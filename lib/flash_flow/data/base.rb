require 'json'
require 'flash_flow/version'
require 'flash_flow/data/branch'
require 'flash_flow/data/collection'
require 'flash_flow/data/store'

module FlashFlow
  module Data
    class Base
      extend Forwardable

      def_delegators :@collection, :add_story, :mergeable, :mark_deleted, :mark_success, :mark_failure,
                     :remove_from_merge, :add_to_merge, :failures, :set_resolutions, :to_a, :can_ship?, :branch_link

      def initialize(branch_config, filename, git, opts={})
        @git = git
        @store = Store.new(filename, git, opts)
        @collection = initialize_collection(branch_config, git.remotes_hash)
      end

      def initialize_collection(branch_config, remotes)
        collection = Collection.fetch(remotes, branch_config) ||
            Collection.from_hash(remotes, backwards_compatible_store['branches'])
        collection.mark_all_as_current
        collection
      end

      def version
        backwards_compatible_store['version']
      end

      def save!
        @store.write(to_hash)
      end

      def to_hash
        {
            'version'  => FlashFlow::VERSION,
            'branches' => merged_branches.to_hash
        }
      end

      def merged_branches
        @collection.reverse_merge(Collection.from_hash({}, backwards_compatible_store['branches']))
      end

      def backwards_compatible_store
        @backwards_compatible_store ||= begin
          hash = in_shadow_repo do
            @store.get
          end

          hash.has_key?('branches') ? hash : { 'branches' => hash }
        end
      end

      def saved_branches
        Collection.from_hash(@git.remotes, backwards_compatible_store['branches']).to_a
      end

      private

      def in_shadow_repo
        ShadowRepo.new(@git).in_dir do
          yield
        end
      end
    end
  end
end