require 'flash_flow/data/branch'
require 'flash_flow/data/github'

module FlashFlow
  module Data

    class Collection

      attr_accessor :branches, :remotes

      def initialize(remotes, config=nil)
        @remotes = remotes
        @branches = {}

        if config && config['class'] && config['class']['name']
          collection_class = Object.const_get(config['class']['name'])
          @collection_instance = collection_class.new(config['class'])
        end
      end

      def self.fetch(remotes, config=nil)
        collection = new(remotes, config)
        collection.fetch
        collection
      end

      def self.from_hash(remotes, hash)
        collection = new(remotes)
        collection.branches = branches_from_hash(hash.dup)
        collection
      end

      def self.branches_from_hash(hash)
        hash.each do |key, val|
          hash[key] = val.is_a?(Branch) ? val : Branch.from_hash(val)
        end
      end

      def get(remote_url, ref)
        @branches[key(remote_url, ref)]
      end

      def to_hash
        {}.tap do |hash|
          @branches.each do |key, val|
            hash[key] = val.to_hash
          end
        end
      end

      def reverse_merge(old)
        merged_branches = @branches.dup

        merged_branches.each do |_, info|
          info.updated_at = Time.now
          info.created_at ||= Time.now
        end

        old.each do |full_ref, info|
          if merged_branches.has_key?(full_ref)
            merged_branches[full_ref].created_at = info.created_at
            merged_branches[full_ref].stories = info.stories.to_a | merged_branches[full_ref].stories.to_a
          else
            merged_branches[full_ref] = info
            merged_branches[full_ref].status = nil
          end
        end

        merged_branches
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
        return unless @collection_instance.respond_to?(:fetch)

        @collection_instance.fetch.each do |b|
          update_or_add(b)
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

      def mark_deleted(branch)
        update_or_add(branch)
        branch.deleted!
        @collection_instance.mark_deleted(branch) if @collection_instance.respond_to?(:mark_deleted)
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

      def set_resolutions(branch, resolutions)
        update_or_add(branch)
        branch.set_resolutions(resolutions)
        @collection_instance.set_resolutions(branch) if @collection_instance.respond_to?(:set_resolutions)
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
        update_or_add(Branch.new(remote, remote_url, ref))
      end

    end
  end
end
