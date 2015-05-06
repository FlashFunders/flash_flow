require 'minitest_helper'

module FlashFlow
  class TestBranchInfo < Minitest::Test

    def setup
      @branch_info = BranchInfo.new
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

  end
end
