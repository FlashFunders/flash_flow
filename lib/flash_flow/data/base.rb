require 'json'
require 'flash_flow/time_helper'
require 'flash_flow/version'
require 'flash_flow/data/branch'
require 'flash_flow/data/collection'
require 'flash_flow/data/store'

module FlashFlow
  module Data
    class Base
      extend Forwardable

      def_delegators :@collection, :add_story, :mergeable, :mark_deleted, :mark_success, :mark_failure,
                     :remove_from_merge, :add_to_merge, :failures, :successes, :removals, :set_resolutions,
                     :to_a, :code_reviewed?, :branch_link

      attr_reader :collection

      def initialize(branch_config, filename, git, opts={})
        @git = git
        @store = Store.new(filename, git, opts)
        @collection = initialize_collection(branch_config)
      end

      def initialize_collection(branch_config)
        stored_collection = Collection.from_hash(stored_branches)

        if ! branch_config.empty?
          collection = Collection.fetch(branch_config)
          # Order matters. We are marking the PRs as current, not the branches stored in the json
          collection.mark_all_as_current
          collection = collection.reverse_merge(stored_collection)

        else
          collection = stored_collection
          collection.mark_all_as_current
        end

        collection.branches.delete_if { |k, v|  TimeHelper.massage_time(v.updated_at) < Time.now - TimeHelper.two_weeks  }

        collection
      end

      def version
        stored_data['version']
      end

      def save!
        @store.write(to_hash)
      end

      def to_hash
        {
            'version'  => FlashFlow::VERSION,
            'branches' => @collection.to_hash,
            'releases' => releases
        }
      end

      def stored_branches
        @stored_branches ||= stored_data['branches'] || {}
      end

      def releases
        @releases ||= stored_data['releases'] || []
      end

      def merged_branches
        @collection.reverse_merge(Collection.from_hash({}, stored_branches))
      end

      def stored_data
        @stored_data ||= @store.get
      end

      def saved_branches
        Collection.from_hash(stored_branches).to_a
      end
    end
  end
end
