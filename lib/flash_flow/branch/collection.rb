require 'flash_flow/branch/base'
require 'flash_flow/branch/github'

module FlashFlow
  module Branch

    class Collection

      attr_accessor :branches, :remotes

      def initialize(remotes, config=nil)
        @remotes = remotes
        @branches = {}

        collection_class_name = config && config['class'] && config['class']['name']
        return unless collection_class_name

        collection_class = Object.const_get(collection_class_name)
        @collection_instance = collection_class.new(config['class'])

        fetch
      end

      def self.from_hash(remotes, hash)
        collection = new(remotes)
        collection.branches = hash.dup
        collection
      end

      def self.merge(old_collection, new_collection)
        old_collection.branches.each do |key, old_branch|
          new_branch = new_collection.branches[key]
          old_branch.merge(new_branch)
        end

        new_collection.branches.each do |key, new_branch|
          unless old_collection.branches.has_key?(key)
            old_collection[key] = new_branch
          end
        end
      end

      def get(remote_url, ref)
        @branches[key(remote_url, ref)]
      end

      def to_a
        @branches.values
      end

      def each
        to_a.each
      end

      def mergeable
        to_a.select { |branch| branch.success? || branch.fail? || branch.unknown? }
      end

      def failures
        @branches.select { |_, v| v.fail? }
      end

      def fetch
        if @collection_instance.respond_to?(:fetch)
          @collection_instance.fetch.each do |b|
            update_or_add(b)
          end
        end
      end

      def add_to_merge(remote, ref)
        branch = record(remote, nil, ref)
        @collection_instance.add_to_merge(branch) if @collection_instance.respond_to?(:add_to_merge)
        branch
      end

      def remove_from_merge(remote, ref)
        branch = record(remote, nil, ref)
        branch.removed!
        @collection_instance.remove_from_merge(branch) if @collection_instance.respond_to?(:remove_from_merge)
        branch
      end

      def mark_failure(branch, conflict_sha=nil)
        update_or_add(branch)
        branch.fail!(conflict_sha)
        @collection_instance.mark_failure(branch) if @collection_instance.respond_to?(:mark_failure)
        branch
      end

      def mark_success(branch)
        update_or_add(branch)
        branch.success!
        @collection_instance.mark_success(branch) if @collection_instance.respond_to?(:mark_success)
        branch
      end

      def add_story(remote, ref, story_id)
        branch = get(url_from_remote(remote), ref)
        branch.stories ||= []
        branch.stories << story_id

        @collection_instance.add_story(branch, story_id) if @collection_instance.respond_to?(:add_story)
        branch
      end

      private

      def key(remote_url, ref)
        "#{remote_url}/#{ref}"
      end

      def remote_from_url(url)
        remotes.detect { |_, url_val| url_val == url }.first
      end

      def url_from_remote(remote)
        remotes[remote]
      end

      def fixup(branch)
        branch.remote ||= remote_from_url(branch.remote_url)
        branch.remote_url ||= url_from_remote(branch.remote)
      end

      def update_or_add(branch)
        fixup(branch)
        old_branch = @branches[key(branch.remote_url, branch.ref)]
        @branches[key(branch.remote_url, branch.ref)] = old_branch.nil? ? branch : old_branch.merge(branch)
      end

      def record(remote, remote_url, ref)
        update_or_add(Branch::Base.new(remote, remote_url, ref))
      end

    end
  end
end
