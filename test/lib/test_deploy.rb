require 'minitest_helper'

module FlashFlow
  class TestDeploy < Minitest::Test

    def setup
      reset_config!
      config!(repo: 'flashfunders/flash_flow')
      @deploy = Deploy.new
    end

    def test_print_errors_with_no_errors
      @deploy.instance_variable_set('@merge_errors'.to_sym, [])
      assert_equal(@deploy.format_errors, 'Success!')
    end

    def test_print_errors_when_current_branch_cant_merge
      @deploy.instance_variable_set('@merge_errors'.to_sym, [['origin', 'pushing_branch']])
      @deploy.instance_variable_set('@working_branch'.to_sym, 'pushing_branch')

      current_branch_error = "\nERROR: Your branch did not merge to #{Config.configuration.merge_branch}. Run the following commands to fix the merge conflict and then re-run this script:\n\n  git checkout #{Config.configuration.merge_branch}\n  git merge pushing_branch\n  # Resolve the conflicts\n  git add <conflicted files>\n  git commit --no-edit"

      assert_equal(@deploy.format_errors, current_branch_error)
    end

    def test_print_errors_when_another_branch_cant_merge
      @deploy.instance_variable_set('@merge_errors'.to_sym, [['origin', 'pushing_branch']])

      other_branch_error = "WARNING: Unable to merge branch origin/pushing_branch to #{Config.configuration.merge_branch} due to conflicts."

      assert_equal(@deploy.format_errors, other_branch_error)
    end

  end
end
