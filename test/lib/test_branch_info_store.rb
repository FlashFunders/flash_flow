require 'minitest_helper'
require 'flash_flow/branch_info_store'

module FlashFlow
  class TestBranchInfoStore < Minitest::Test
    def sample_branches
      {
          'origin/branch 1' => {'branch' => 'branch 1', 'remote' => 'origin', 'status' => 'success', 'stories' => ['123']},
          'other_origin/branch 2' => {'branch' => 'branch 2', 'remote' => 'origin', 'status' => 'success', 'stories' => ['456']}
      }
    end

    def setup
      @mock_git = MockGit.new
      @storage = BranchInfoStore.new('/dev/null', @mock_git)
    end

    def test_merge_when_old_is_empty
      branch_info = BranchInfo.new
      branch_info.mark_success('origin', 'some_branch')

      merged = @storage.merge({}, branch_info.branches)
      assert_equal(['origin/some_branch'], merged.keys)
      assert_equal('success', merged['origin/some_branch']['status'])
    end

    def test_merge_old_marks_old_branches
      branch_info = BranchInfo.new
      branch_info.mark_success('origin', 'some_branch')
      merged = @storage.merge(old_branches, branch_info.branches)

      assert_equal('Unknown', merged['origin/some_old_branch']['status'])
    end

    def test_merge_old_adds_new_stories
      branch_info = BranchInfo.new
      branch_info.mark_success('origin', 'some_branch')
      branch_info.add_story('origin', 'some_branch', '456')
      merged = @storage.merge(old_branches, branch_info.branches)

      assert_equal(['222', '456'], merged['origin/some_branch']['stories'])
    end

    def test_merge_old_uses_old_created_at
      branch_info = BranchInfo.new
      branch_info.mark_success('origin', 'some_branch')
      branch_info.mark_success('origin', 'some_new_branch')
      merged = @storage.merge(old_branches, branch_info.branches)

      assert_equal(old_branches['origin/some_branch']['created_at'], merged['origin/some_branch']['created_at'])
      # Assert the new branch is created_at within the last minute
      assert(merged['origin/some_new_branch']['created_at'] > (Time.now - 60))
    end

    def test_merge_old_uses_new_status
      branch_info = BranchInfo.new
      branch_info.mark_failure('origin', 'some_branch', 'conflict_sha')
      merged = @storage.merge(old_branches, branch_info.branches)

      assert_equal('fail', merged['origin/some_branch']['status'])
    end

    def test_get
      @mock_git.stub(:read_file_from_merge_branch, JSON.pretty_generate(sample_branches)) do
        assert_equal(@storage.get, sample_branches)
      end
    end

    def test_write
      str = StringIO.new
      @storage.write(sample_branches, str)

      assert_equal(str.string.strip, JSON.pretty_generate(sample_branches).strip)
    end

    private # Helpers

    def old_branches
      @old_branches ||= {
          'origin/some_old_branch' => {'branch' => 'some_branch', 'remote' => 'origin', 'status' => 'success', 'created_at' => (Time.now - 3600), 'stories' => ['111']},
          'origin/some_branch' => {'branch' => 'some_branch', 'remote' => 'origin', 'status' => 'success', 'created_at' => (Time.now - 1800), 'stories' => ['222']}
      }
    end
  end

  class MockGit
    def read_file_from_merge_branch;
    end

    def in_merge_branch
      yield
    end
  end
end
