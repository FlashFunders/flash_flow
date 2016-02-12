require 'minitest_helper'
require 'minitest/stub_any_instance'

module FlashFlow
  class TestMergeOrder < Minitest::Test

    def setup
      @git = Minitest::Mock.new
    end

    def test_get_order_unchanged_shas_get_ordered_as_previous
      mock_working_branch(sample_branches[2])
      mock_current_sha(sample_branches[1], sample_branches[1].sha)
      mock_current_sha(sample_branches[0], sample_branches[0].sha)

      ordered_branches = MergeOrder.new(@git, mergeable_order(1,0,2)).get_order
      assert_equal(ordered_branches, mergeable_order(1,0,2))
    end

    def test_get_order_working_branch_is_always_last
      mock_working_branch(sample_branches[0])
      mock_current_sha(sample_branches[1], sample_branches[1].sha)
      mock_current_sha(sample_branches[2], sample_branches[2].sha)

      ordered_branches = MergeOrder.new(@git, mergeable_order(1,0,2)).get_order
      assert_equal(ordered_branches, mergeable_order(1,2,0))
    end

    def test_get_order_changed_shas_are_between_unchanged_shas_and_working_branch
      mock_working_branch(sample_branches[1])
      mock_current_sha(sample_branches[2], sample_branches[2].sha)
      mock_current_sha(sample_branches[0], sample_branches[0].sha)

      sample_branches[2].sha = 'sha2-1'

      ordered_branches = MergeOrder.new(@git, mergeable_order(2,1,0)).get_order
      assert_equal(ordered_branches, mergeable_order(0,2,1))
    end

    private

    def mock_current_sha(branch, sha)
      @git.expect(:run, sha, ["rev-parse #{branch.remote}/#{branch.ref}"])
        .expect(:last_success?, true)
        .expect(:last_stdout, sha)
    end

    def mock_working_branch(branch)
      sample_branches.count.times { @git.expect(:working_branch, branch.ref) }
    end

    def sample_branches
      @sample_branches ||= [Data::Branch.from_hash({'ref' => 'branch0', 'remote' => 'origin', 'sha' => 'sha0', 'status' => 'success'}),
        Data::Branch.from_hash({'ref' => 'branch1', 'remote' => 'origin', 'sha' => 'sha1', 'status' => 'unknown'}),
        Data::Branch.from_hash({'ref' => 'branch2', 'remote' => 'origin', 'sha' => 'sha2', 'status' => 'fail'})]
    end

    def mergeable_order(*order)
      order.map { |index| sample_branches[index] }
    end

  end
end
