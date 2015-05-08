require 'minitest_helper'
require 'minitest/stub_any_instance'

module FlashFlow
  class TestDeploy < Minitest::Test

    def setup
      reset_config!
      config!(repo: 'flashfunders/flash_flow', locking_issue_id: 1, merge_branch: 'test_acceptance')

      @deploy = Deploy.new
    end

    def test_print_errors_with_no_errors
      branch_info = Minitest::Mock.new
      branch_info.expect(:failures, { } )
      assert_equal(@deploy.format_errors, 'Success!')
    end

    def test_print_errors_when_current_branch_cant_merge
      branch_info = Minitest::Mock.new
      branch_info.expect(:failures, { 'origin/pushing_branch' => { 'branch' => 'pushing_branch', 'remote' => 'origin', 'status' => 'failures', 'stories' => [] }} )

      @deploy.instance_variable_set('@branch_info'.to_sym, branch_info)
      @deploy.instance_variable_set('@working_branch'.to_sym, 'pushing_branch')

      current_branch_error = "\nERROR: Your branch did not merge to #{Config.configuration.merge_branch}. Run the following commands to fix the merge conflict and then re-run this script:\n\n  git checkout #{Config.configuration.merge_branch}\n  git merge pushing_branch\n  # Resolve the conflicts\n  git add <conflicted files>\n  git commit --no-edit"

      assert_equal(@deploy.format_errors, current_branch_error)
    end

    def test_print_errors_when_another_branch_cant_merge
      branch_info = Minitest::Mock.new
      branch_info.expect(:failures, { 'origin/pushing_branch' => { 'branch' => 'pushing_branch', 'remote' => 'origin', 'status' => 'failures', 'stories' => [] }} )

      @deploy.instance_variable_set('@branch_info'.to_sym, branch_info)

      other_branch_error = "WARNING: Unable to merge branch origin/pushing_branch to #{Config.configuration.merge_branch} due to conflicts."

      assert_equal(@deploy.format_errors, other_branch_error)
    end

    def test_check_out_to_working_branch
      @deploy.stub(:check_repo, true) do
        Github.stub_any_instance(:issue_open?, true) do
          Github.stub_any_instance(:get_last_event, {actor: {login: 'anonymous'}, created_at: Time.now }) do
            assert_output(/started running flash_flow/) { @deploy.run }
            @deploy.cmd_runner.expect(:run, true, ['git checkout pushing_branch'])
          end
        end
      end
    end

    def test_merge_conflict_notification
      pull_request = {
        ref: 'feature/test',
        number: 1,
        user_url: 'https://github.com/_someone',
        repo_url: 'https://github.com/org/fake_repo'
      }

      branch_info = Minitest::Mock.new
      branch_info.expect(:mark_failure, true, ['origin', pull_request[:ref]])
      @deploy.instance_variable_set('@branch_info'.to_sym, branch_info)

      hipchat = Minitest::Mock.new
      hipchat.expect(:notify_merge_conflict, true, [pull_request[:user_url], pull_request[:repo_url], pull_request[:ref]])
      @deploy.instance_variable_set('@hipchat'.to_sym, hipchat)

      @deploy.stub(:merge_success?, false) do
        @deploy.stub(:working_pull_request, false) do
          Github.stub_any_instance(:add_unmergeable_label, true) do
            @deploy.git_merge('origin', pull_request)
          end
        end

        assert(branch_info.verify)
        assert(hipchat.verify)
      end
    end

    def test_ignore_pushing_master_or_acceptance
      ['master', 'test_acceptance'].each do |branch|
        @deploy.instance_variable_set('@working_branch'.to_sym, branch)
        refute(@deploy.open_pull_request)
      end
    end
  end
end
