require 'minitest_helper'

module FlashFlow
  class TestBranchInfo < Minitest::Test
    def sample_branches
      {
          'origin/branch 1' => { 'branch' => 'branch 1', 'remote' => 'origin', 'status' => 'success', 'stories' => ['123'] },
          'other_origin/branch 2' => { 'branch' => 'branch 2', 'remote' => 'origin', 'status' => 'success', 'stories' => ['456'] }
      }
    end

    def setup
      @branch_info = BranchInfo.new('testfile')
    end

    def test_mark_success_existing_branch
      @branch_info.mark_failure('origin', 'some_branch')
      @branch_info.mark_success('origin', 'some_branch')
      assert_equal(@branch_info.branches['origin/some_branch']['status'], 'success')
    end

    def test_mark_success_new_branch
      @branch_info.mark_success('origin', 'some_branch')
      assert_equal(@branch_info.branches['origin/some_branch']['status'], 'success')
    end

    def test_mark_failure_existing_branch
      @branch_info.mark_success('origin', 'some_branch')
      @branch_info.mark_failure('origin', 'some_branch')
      assert_equal(@branch_info.branches['origin/some_branch']['status'], 'fail')
    end

    def test_mark_failure_new_branch
      @branch_info.mark_failure('origin', 'some_branch')
      assert_equal(@branch_info.branches['origin/some_branch']['status'], 'fail')
    end

    def test_add_story
      @branch_info.add_story('origin', 'some_branch', '999')
      assert_equal(@branch_info.branches['origin/some_branch']['stories'], ['999'])
    end

    def test_failures
      @branch_info.mark_failure('origin', 'some_branch1')
      @branch_info.mark_success('origin', 'some_branch2')
      @branch_info.mark_failure('origin', 'some_branch3')

      assert_equal(@branch_info.failures.keys, ['origin/some_branch1', 'origin/some_branch3'])
    end

    def test_merge_original_when_original_is_empty
      BranchInfoStore.stub(:new, stub_storage({})) do
        branch_info = BranchInfo.new('/dev/null')
        branch_info.mark_success('origin', 'some_branch')
        branch_info.load_original
        merged = branch_info.merge_original
        assert_equal(['origin/some_branch'], merged.keys)
        assert_equal('success', merged['origin/some_branch']['status'])
      end
    end

    def test_merge_original_marks_old_branches
      BranchInfoStore.stub(:new, stub_storage) do
        branch_info = BranchInfo.new('/dev/null')
        branch_info.mark_success('origin', 'some_branch')
        branch_info.load_original
        merged = branch_info.merge_original
        assert_equal('Unknown', merged['origin/some_old_branch']['status'])
      end
    end

    def test_merge_original_adds_new_stories
      BranchInfoStore.stub(:new, stub_storage) do
        branch_info = BranchInfo.new('/dev/null')
        branch_info.mark_success('origin', 'some_branch')
        branch_info.add_story('origin', 'some_branch', '456')
        branch_info.load_original
        merged = branch_info.merge_original
        assert_equal(['222', '456'], merged['origin/some_branch']['stories'])
      end
    end

    def test_merge_original_uses_old_created_at
      BranchInfoStore.stub(:new, stub_storage) do
        branch_info = BranchInfo.new('/dev/null')
        branch_info.mark_success('origin', 'some_branch')
        branch_info.mark_success('origin', 'some_new_branch')
        branch_info.load_original
        merged = branch_info.merge_original
        assert_equal(old_branches['origin/some_branch']['created_at'], merged['origin/some_branch']['created_at'])
        # Assert the new branch is created_at within the last minute
        assert(merged['origin/some_new_branch']['created_at'] > (Time.now - 60))
      end
    end

    def test_merge_original_uses_new_status
      BranchInfoStore.stub(:new, stub_storage) do
        branch_info = BranchInfo.new('/dev/null')
        branch_info.mark_failure('origin', 'some_branch')
        branch_info.load_original
        merged = branch_info.merge_original
        assert_equal('fail', merged['origin/some_branch']['status'])
      end
    end

    private # Helpers

    def stub_storage(stub_with=old_branches)
      storage = Minitest::Mock.new
      storage.expect(:get, stub_with)
      storage
    end

    def old_branches
      @old_branches ||= {
          'origin/some_old_branch' => {'branch' => 'some_branch', 'remote' => 'origin', 'status' => 'success', 'created_at' => (Time.now - 3600), 'stories' => ['111']},
          'origin/some_branch' => {'branch' => 'some_branch', 'remote' => 'origin', 'status' => 'success', 'created_at' => (Time.now - 1800), 'stories' => ['222']}
      }
    end
  end
end
