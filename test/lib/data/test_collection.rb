require 'minitest_helper'

module FlashFlow
  module Data
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
        @fake_branches = FakeBranches.branches
        @branch = Branch.new('some_branch')
        @collection = Collection.new({ 'class' => { 'name' => 'FakeBranches' }})
      end

      def test_from_hash_set_branches
        hash = { 'some_branch' => Branch.new('some_branch') }
        assert_equal(Collection.from_hash(hash).branches, hash)
      end

      def test_fetch_calls_collection_class
        @fake_branches.expect(:fetch, [], [])
        @collection.fetch

        @fake_branches.verify
      end

      def test_fetch_returns_nil_if_no_collection_class
        assert_nil(@collection.fetch)
      end

      def test_fetch_maps_collection_class_to_branches
        branch = Data::Branch.new('some_branch')
        @fake_branches.expect(:fetch, [Branch.from_hash({'ref' => branch.ref })], [])
        @collection.fetch

        assert_equal(@collection.branches.values, [branch])
        @fake_branches.verify
      end

      def test_reverse_merge_when_old_is_empty
        @collection.mark_success(@branch)

        merged = @collection.reverse_merge(Collection.from_hash({}))
        assert_equal(['some_branch'], merged.to_h.keys)
        assert(merged.get('some_branch').success?)
      end

      def test_reverse_merge_old_marks_old_branches
        @collection.mark_success(@branch)

        merged = @collection.reverse_merge(Collection.from_hash(old_branches))
        assert(merged.get('some_old_branch').unknown?)
      end

      def test_reverse_merge_old_adds_new_stories
        @collection.mark_success(@branch)
        @collection.add_story('some_branch', '456')
        merged = @collection.reverse_merge(Collection.from_hash(old_branches))

        assert_equal(['222', '456'], merged.get('some_branch').stories)
      end

      def test_reverse_merge_old_uses_old_created_at
        @collection.add_to_merge('some_old_branch')
        @collection.add_to_merge('some_new_branch')
        old_branch_collection = Collection.from_hash(old_branches)
        merged = @collection.reverse_merge(old_branch_collection)

        assert_equal(old_branch_collection.get('some_branch').created_at, merged.get('some_branch').created_at)
        # Assert the new branch is created_at within the last minute
        assert(merged.get('some_new_branch').created_at > (Time.now - 60))
      end

      def test_reverse_merge_old_uses_new_status
        @collection.mark_failure(old_branches['some_branch'])
        merged = @collection.reverse_merge(Collection.from_hash(old_branches))

        assert(merged.get('some_branch').fail?)
      end

      def test_fetch_returns_a_collection_instance
        FakeBranches.branches.expect(:fetch, [])
        collection = Collection.fetch({ 'class' => { 'name' => 'FakeBranches' }})
        assert(collection.is_a?(Collection))
      end

      def test_add_to_merge_new_branch
        @collection.add_to_merge('some_branch')
        assert_equal(@collection.get('some_branch').ref, 'some_branch')
      end

      def test_add_to_merge_existing_branch
        @collection.mark_failure(@branch)
        @collection.add_to_merge(@branch.ref)

        assert_equal(@collection.get(@branch.ref), @branch)
      end

      def test_add_to_merge_calls_branches_class
        @fake_branches.expect(:add_to_merge, true, [@branch])
        @collection.add_to_merge(@branch.ref)

        @fake_branches.verify
      end

      def test_remove_from_merge_new_branch
        @collection.remove_from_merge(@branch.ref)
        assert(@collection.get(@branch.ref).removed?)
      end

      def test_remove_from_merge_existing_branch
        @collection.mark_success(@branch)
        assert(@collection.get(@branch.ref).success?)
        @collection.remove_from_merge(@branch.ref)
        assert(@collection.get(@branch.ref).removed?)
      end

      def test_remove_from_merge_calls_branches_class
        @fake_branches.expect(:remove_from_merge, true, [@branch])
        @collection.remove_from_merge(@branch.ref)
        @fake_branches.verify
      end

      def test_mark_success_new_branch
        @collection.mark_success(@branch)
        assert(@collection.get(@branch.ref).success?)
      end

      def test_mark_success_existing_branch
        branch = @collection.add_to_merge(@branch.ref)
        @collection.mark_failure(branch)
        @collection.mark_success(branch)
        assert(@collection.get(@branch.ref).success?)
      end

      def test_mark_success_calls_branches_class
        @fake_branches.expect(:mark_success, true, [@branch])
        @collection.mark_success(@branch)
        @fake_branches.verify
      end

      def test_mark_failure_existing_branch
        branch = @collection.add_to_merge(@branch.ref)
        @collection.mark_success(branch)
        @collection.mark_failure(branch)
        assert(@collection.get(@branch.ref).fail?)
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
        assert(@collection.get(@branch.ref).deleted?)
      end

      def test_mark_deleted_existing_branch
        branch = @collection.add_to_merge(@branch.ref)
        @collection.mark_failure(branch)
        @collection.mark_deleted(branch)
        assert(@collection.get(@branch.ref).deleted?)
      end

      def test_mark_deleted_calls_branches_class
        @fake_branches.expect(:mark_deleted, true, [@branch])
        @collection.mark_deleted(@branch)
        @fake_branches.verify
      end

      def test_add_story
        @collection.add_to_merge('some_branch')
        @collection.add_story('some_branch', '999')
        assert_equal(@collection.get('some_branch').stories, ['999'])
      end

      def test_add_story_calls_branches_class
        @fake_branches.expect(:add_story, true, [@branch, '999'])
        @collection.add_to_merge('some_branch')
        @collection.add_story('some_branch', '999')
        @fake_branches.verify
      end

      def test_code_reviewd_returns_true
        collection = Collection.new({})
        assert(collection.code_reviewed?(@branch))
      end

      def test_code_reviewd_calls_branches_class
        @fake_branches.expect(:code_reviewed?, true, [@branch])
        @collection.code_reviewed?(@branch)
        @fake_branches.verify
      end

      def test_branch_link_returns_nil
        collection = Collection.new({})
        assert_nil(collection.branch_link(@branch))
      end

      def test_branch_link_calls_branches_class
        @fake_branches.expect(:branch_link, 'http://link_to_branch.com', [@branch])
        assert_equal('http://link_to_branch.com', @collection.branch_link(@branch))
        @fake_branches.verify
      end

      def test_current_branches
        branch1 = Branch.new('111')
        branch2 = Branch.new('222')
        branch3 = Branch.new('333')
        branch2.current_record = true
        @collection.mark_success(branch1)
        @collection.mark_success(branch2)
        @collection.mark_success(branch3)

        assert_equal(@collection.current_branches, [branch2])
      end

      def test_mark_all_as_current
        branch1 = Branch.new('111')
        branch2 = Branch.new('222')
        branch3 = Branch.new('333')
        branch2.current_record = true
        @collection.mark_success(branch1)
        @collection.mark_success(branch2)
        @collection.mark_success(branch3)

        assert_equal(@collection.current_branches, [branch2])

        @collection.mark_all_as_current

        assert_equal(@collection.current_branches, [branch1, branch2, branch3])
      end

      def test_failures
        mark_branches

        assert_equal(@collection.failures, [fail1, fail2])
      end

      def test_successes
        mark_branches

        assert_equal(@collection.successes, [success1, success2])
      end

      def test_removals
        mark_branches

        assert_equal(@collection.removals, [removed1])
      end

      private

      def mark_branches
        @collection.mark_failure(fail1)
        @collection.mark_success(success1)
        @collection.mark_failure(fail2)
        @removed1 = @collection.remove_from_merge(removed1.ref)
        @collection.mark_success(success2)
        @collection.mark_all_as_current
      end

      def fail1
        @fail1 ||= Branch.new('111')
      end

      def fail2
        @fail2 ||= Branch.new('333')
      end

      def success1
        @success1 ||= Branch.new('222')
      end

      def success2
        @success2 ||= Branch.new('555')
      end

      def removed1
        @removed1 ||= Branch.new('444')
      end

      def old_branches
        @old_branches ||= {
            'some_old_branch' => Branch.from_hash({'ref' => 'some_old_branch', 'created_at' => (Time.now - 3600), 'stories' => ['111']}),
            'some_branch' => Branch.from_hash({'ref' => 'some_branch', 'status' => 'success', 'created_at' => (Time.now - 1800), 'stories' => ['222']})
        }
      end
    end
  end
end
