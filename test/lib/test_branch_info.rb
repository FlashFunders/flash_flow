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

    def test_merge_and_save_when_original_is_empty
      storage = Minitest::Mock.new
      storage.expect(:write, true, [ { 'origin/some_branch' => { 'branch' => 'some_branch', 'remote' => 'origin', 'status' => 'success', 'stories' => [] }} ])
      storage.expect(:get, {})

      BranchInfoStore.stub(:new, storage) do
        branch_info = BranchInfo.new('/dev/null')
        branch_info.mark_success('origin', 'some_branch')
        branch_info.merge_and_save
      end

      storage.verify
    end

    def test_merge_and_save_removes_old_branches
      storage = Minitest::Mock.new
      storage.expect(:write, true, [ { 'origin/some_branch' => { 'branch' => 'some_branch', 'remote' => 'origin', 'status' => 'success', 'stories' => [] }} ])
      storage.expect(:get, { 'origin/some_old_branch' => { 'branch' => 'some_old_branch', 'remote' => 'origin', 'status' => 'success' }})

      BranchInfoStore.stub(:new, storage) do
        branch_info = BranchInfo.new('/dev/null')
        branch_info.mark_success('origin', 'some_branch')
        branch_info.merge_and_save
      end

      storage.verify
    end

    def test_merge_and_save_adds_new_stories
      storage = Minitest::Mock.new
      storage.expect(:write, true, [ { 'origin/some_branch' => { 'branch' => 'some_branch', 'remote' => 'origin', 'status' => 'success', 'stories' => ['123', '456'] }} ])
      storage.expect(:get, { 'origin/some_branch' => { 'branch' => 'some_branch', 'remote' => 'origin', 'status' => 'success', 'stories' => ['123'] }})

      BranchInfoStore.stub(:new, storage) do
        branch_info = BranchInfo.new('/dev/null')
        branch_info.mark_success('origin', 'some_branch')
        branch_info.add_story('origin', 'some_branch', '456')
        branch_info.merge_and_save
      end

      storage.verify
    end

  end
end
