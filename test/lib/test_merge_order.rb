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
      mock_current_sha(sample_branches[2], sample_branches[2].sha)

      ordered_branches = MergeOrder.new(@git, mergeable_order(1,0,2)).get_order
      assert_equal(ordered_branches.map(&:sha), mergeable_order(1,0,2).map(&:sha))
    end

    def test_get_order_changed_working_branch_is_always_last
      mock_working_branch(sample_branches[0])
      mock_current_sha(sample_branches[1], sample_branches[1].sha)
      mock_current_sha(sample_branches[0], sample_branches[0].sha)
      mock_current_sha(sample_branches[2], sample_branches[2].sha)

      sample_branches[0].sha = 'sha0-1'

      ordered_branches = MergeOrder.new(@git, mergeable_order(1,0,2)).get_order
      assert_equal(ordered_branches.map(&:sha), mergeable_order(1,2,0).map(&:sha))
    end
    #
    def test_get_order_changed_shas_are_between_unchanged_shas_and_changed_working_branch
      mock_working_branch(sample_branches[1])
      mock_current_sha(sample_branches[2], sample_branches[2].sha)
      mock_current_sha(sample_branches[1], sample_branches[1].sha)
      mock_current_sha(sample_branches[0], sample_branches[0].sha)

      sample_branches[1].sha = 'sha0-1'
      sample_branches[2].sha = 'sha2-1'

      ordered_branches = MergeOrder.new(@git, mergeable_order(2,1,0)).get_order
      assert_equal(ordered_branches.map(&:sha), mergeable_order(0,2,1).map(&:sha))
    end

    private

    def mock_current_sha(branch, sha)
      @git.expect(:remote, 'origin')
      @git.expect(:get_sha, sha, ["origin/#{branch.ref}"])
    end

    def mock_working_branch(branch)
      sample_branches.count.times { @git.expect(:working_branch, branch.ref) }
    end

    def sample_branches
      @sample_branches ||= [Data::Branch.from_hash({'ref' => 'branch0', 'sha' => 'sha0', 'merge_order' => 1}),
        Data::Branch.from_hash({'ref' => 'branch1', 'sha' => 'sha1', 'merge_order' => 2}),
        Data::Branch.from_hash({'ref' => 'branch2', 'sha' => 'sha2', 'merge_order' => 3})]
    end

    def mergeable_order(*order)
      order.map.with_index do |nth, merge_order|
        sample_branches[nth].merge_order = (merge_order == 2 ? nil : merge_order)
        sample_branches[nth]
      end
    end

  end
end
