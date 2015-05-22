require 'minitest_helper'

module FlashFlow
  module Branch
    class TestCollection < Minitest::Test

      def setup_fake_branches
        Object.send(:remove_const, :FakeBranches) if Object.const_defined?(:FakeBranches)

        fake_branches_class = Class.new do
          @branches = Minitest::Mock.new
          def self.new(opts=nil); @branches; end
          def self.branches; @branches; end
        end
        Object.const_set('FakeBranches', fake_branches_class)
      end

      def setup
        setup_fake_branches
        @fake_store = Minitest::Mock.new
        @fake_branches = FakeBranches.branches
        @branch = Base.new('origin', 'the_origin_url', 'some_branch')
        @collection = Collection.new({ 'origin' => 'the_origin_url' }, @fake_store, { 'class' => { 'name' => 'FakeBranches' }})
      end

      def test_from_hash_set_branches
        hash = { 'some_url/some_branch' => Base.new('origin', 'the_origin_url', 'some_branch') }
        assert_equal(Collection.from_hash({}, @fake_store, hash).branches, hash)
      end

      def test_from_hash_set_remotes
        remotes = { 'some_remote' => 'some_remote_url' }
        assert_equal(Collection.from_hash(remotes, @fake_store, {}).remotes, remotes)
      end

      def test_fetch_calls_collection_class
        @fake_branches.expect(:fetch, [], [])
        @collection.fetch

        @fake_branches.verify
      end

      def test_fetch_calls_store_if_no_collection_class
        @fake_store.expect(:fetch, [], [])
        @collection.fetch

        @fake_store.verify
      end

      def test_fetch_maps_collection_class_to_branches
        branch = Branch::Base.new('origin', 'the_origin_url', 'some_branch')
        @fake_branches.expect(:fetch, [Base.from_hash({'remote' => branch.remote, 'remote_url' => branch.remote_url, 'ref' => branch.ref })], [])
        @collection.fetch

        assert_equal(@collection.branches.values, [branch])
        @fake_branches.verify
      end

      def test_fetch_finds_the_remote
        branch = Branch::Base.new('origin', 'the_origin_url', 'some_branch')
        @fake_branches.expect(:fetch, [Base.from_hash({'remote_url' => branch.remote_url, 'ref' => branch.ref })], [])
        @collection.fetch

        assert_equal(@collection.branches.values, [branch])
        @fake_branches.verify
      end

      def test_save!
        @collection.mark_success(@branch)
        @fake_store.expect(:merge_and_save, true, [@collection.branches])

        @collection.save!
      end

      def test_fetch_returns_a_collection_instance
        FakeBranches.branches.expect(:fetch, [])
        collection = Collection.fetch({ 'origin' => 'the_origin_url' }, @fake_store, { 'class' => { 'name' => 'FakeBranches' }})
        assert(collection.is_a?(Collection))
      end

      def test_add_to_merge_new_branch
        @collection.add_to_merge('origin', 'some_branch')
        assert_equal(@collection.get('the_origin_url', 'some_branch').ref, 'some_branch')
        assert_equal(@collection.get('the_origin_url', 'some_branch').remote, 'origin')
        assert_equal(@collection.get('the_origin_url', 'some_branch').remote_url, 'the_origin_url')
      end

      def test_add_to_merge_existing_branch
        @collection.mark_failure(@branch)
        @collection.add_to_merge(@branch.remote, @branch.ref)

        assert_equal(@collection.get(@branch.remote_url, @branch.ref), @branch)
      end

      def test_add_to_merge_calls_branches_class
        @fake_branches.expect(:add_to_merge, true, [@branch])
        @collection.add_to_merge(@branch.remote, @branch.ref)

        @fake_branches.verify
      end

      def test_remove_from_merge_new_branch
        @collection.remove_from_merge(@branch.remote, @branch.ref)
        assert(@collection.get(@branch.remote_url, @branch.ref).removed?)
      end

      def test_remove_from_merge_existing_branch
        @collection.mark_success(@branch)
        assert(@collection.get(@branch.remote_url, @branch.ref).success?)
        @collection.remove_from_merge(@branch.remote, @branch.ref)
        assert(@collection.get(@branch.remote_url, @branch.ref).removed?)
      end

      def test_remove_from_merge_calls_branches_class
        @fake_branches.expect(:remove_from_merge, true, [@branch])
        @collection.remove_from_merge(@branch.remote, @branch.ref)
        @fake_branches.verify
      end

      def test_mark_success_new_branch
        @collection.mark_success(@branch)
        assert(@collection.get(@branch.remote_url, @branch.ref).success?)
      end

      def test_mark_success_existing_branch
        branch = @collection.add_to_merge(@branch.remote, @branch.ref)
        @collection.mark_failure(branch)
        @collection.mark_success(branch)
        assert(@collection.get(@branch.remote_url, @branch.ref).success?)
      end

      def test_mark_success_calls_branches_class
        @fake_branches.expect(:mark_success, true, [@branch])
        @collection.mark_success(@branch)
        @fake_branches.verify
      end

      def test_mark_failure_existing_branch
        branch = @collection.add_to_merge(@branch.remote, @branch.ref)
        @collection.mark_success(branch)
        @collection.mark_failure(branch)
        assert(@collection.get(@branch.remote_url, @branch.ref).fail?)
      end

      def test_mark_failure_new_branch
        @collection.mark_failure(@branch)
        assert(@branch.fail?)
      end

      def test_mark_failure_calls_branches_class
        @fake_branches.expect(:mark_failure, true, [@branch])
        @collection.mark_failure(@branch)
        @fake_branches.verify
      end

      def test_mark_deleted_new_branch
        @collection.mark_deleted(@branch)
        assert(@collection.get(@branch.remote_url, @branch.ref).deleted?)
      end

      def test_mark_deleted_existing_branch
        branch = @collection.add_to_merge(@branch.remote, @branch.ref)
        @collection.mark_failure(branch)
        @collection.mark_deleted(branch)
        assert(@collection.get(@branch.remote_url, @branch.ref).deleted?)
      end

      def test_mark_deleted_calls_branches_class
        @fake_branches.expect(:mark_deleted, true, [@branch])
        @collection.mark_deleted(@branch)
        @fake_branches.verify
      end

      def test_add_story
        @collection.add_to_merge('origin', 'some_branch')
        @collection.add_story('origin', 'some_branch', '999')
        assert_equal(@collection.get('the_origin_url', 'some_branch').stories, ['999'])
      end

      def test_add_story_calls_branches_class
        @fake_branches.expect(:add_story, true, [@branch, '999'])
        @collection.add_to_merge('origin', 'some_branch')
        @collection.add_story('origin', 'some_branch', '999')
        @fake_branches.verify
      end

      def test_failures
        branch1 = Base.new('111', '111', '111')
        branch2 = Base.new('222', '222', '222')
        branch3 = Base.new('333', '333', '333')
        @collection.mark_failure(branch1)
        @collection.mark_success(branch2)
        @collection.mark_failure(branch3)

        assert_equal(@collection.failures.values, [branch1, branch3])
      end

    end
  end
end
