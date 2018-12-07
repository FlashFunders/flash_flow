require 'flash_flow/data/branch'
require 'flash_flow/data/github'
require 'flash_flow/data/bitbucket'

module FlashFlow
  module Data

    class Collection

      attr_accessor :branches

      def initialize(config=nil)
        @branches = {}

        if config && config['class'] && config['class']['name']
          collection_class = Object.const_get(config['class']['name'])
          @collection_instance = collection_class.new(config['class'])
        end
      end

      def self.fetch(config=nil)
        collection = new(config)
        collection.fetch
        collection
      end

      def self.from_hash(hash, collection_instance=nil)
        collection = new
        collection.branches = branches_from_hash(hash)
        collection.instance_variable_set(:@collection_instance, collection_instance)
        collection
      end

      def self.branches_from_hash(hash)
        {}.tap do |new_branches|
          hash.each do |_, val|
            branch = val.is_a?(Branch) ? val : Branch.from_hash(val)
            new_branches[branch.ref] = branch
          end
        end
      end

      def self.key(ref)
        ref
      end

      def get(ref)
        @branches[key(ref)]
      end

      def to_hash
        {}.tap do |hash|
          @branches.each do |key, val|
            hash[key] = val.to_hash
          end
        end
      end
      alias :to_h :to_hash

      def reverse_merge(old)
        merged_branches = @branches.dup

        merged_branches.each do |_, info|
          info.updated_at = Time.now
          info.created_at ||= Time.now
        end

        old.branches.each do |full_ref, info|
          if merged_branches.has_key?(full_ref)
            branch = merged_branches[full_ref]

            branch.created_at = info.created_at
            branch.resolutions = info.resolutions.to_h.merge(branch.resolutions.to_h)
            branch.stories = info.stories.to_a | merged_branches[full_ref].stories.to_a
            branch.merge_order ||= info.merge_order
            if branch.fail?
              branch.conflict_sha ||= info.conflict_sha
            end
          else
            merged_branches[full_ref] = info
            merged_branches[full_ref].status = nil
          end
        end

        self.class.from_hash(merged_branches, @collection_instance)
      end

      def to_a
        @branches.values
      end

      def each
        to_a.each
      end

      def current_branches
        to_a.select { |branch| branch.current_record }
      end

      def mergeable
        current_branches.select { |branch| (branch.success? || branch.fail? || branch.unknown?) }
      end

      def failures
        current_branches.select { |branch| branch.fail? }
      end

      def successes
        current_branches.select { |branch| branch.success? }
      end

      def removals
        to_a.select { |branch| branch.removed? }
      end

      def fetch
        return unless @collection_instance.respond_to?(:fetch)

        @collection_instance.fetch.each do |b|
          update_or_add(b)
        end
      end

      def mark_all_as_current
        @branches.each do |_, branch|
          branch.current_record = true
        end
      end

      def add_to_merge(ref)
        branch = record(ref)
        branch.current_record = true
        @collection_instance.add_to_merge(branch) if @collection_instance.respond_to?(:add_to_merge)
        branch
      end

      def remove_from_merge(ref)
        branch = record(ref)
        branch.current_record = true
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

      def add_story(ref, story_id)
        branch = get(ref)
        branch.stories ||= []
        branch.stories << story_id

        @collection_instance.add_story(branch, story_id) if @collection_instance.respond_to?(:add_story)
        branch
      end

      def code_reviewed?(branch)
        @collection_instance.respond_to?(:code_reviewed?) ? @collection_instance.code_reviewed?(branch) : true
      end

      def can_ship?(branch)
        @collection_instance.respond_to?(:can_ship?) ? @collection_instance.can_ship?(branch) : true
      end

      def branch_link(branch)
        @collection_instance.branch_link(branch) if @collection_instance.respond_to?(:branch_link)
      end

      def set_resolutions(branch, resolutions)
        update_or_add(branch)
        branch.set_resolutions(resolutions)
        @collection_instance.set_resolutions(branch) if @collection_instance.respond_to?(:set_resolutions)
        branch
      end

      private

      def key(ref)
        self.class.key(ref)
      end

      def update_or_add(branch)
        old_branch = @branches[key(branch.ref)]
        @branches[key(branch.ref)] = old_branch.nil? ? branch : old_branch.merge(branch)
      end

      def record(ref)
        update_or_add(Branch.new(ref))
      end

    end
  end
end
