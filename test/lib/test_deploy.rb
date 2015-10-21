require 'minitest_helper'
require 'minitest/stub_any_instance'

module FlashFlow
  class TestDeploy < Minitest::Test

    def setup
      reset_config!
      config!(git: {
                  'merge_branch' => 'test_acceptance',
                  'merge_remote' => 'test_remote',
                  'master_branch' => 'test_master',
                  'remotes' => ['fake_origin'],
                  'use_rerere' => true
              })

      @branch = Data::Branch.from_hash({'ref' => 'pushing_branch', 'remote' => 'origin', 'status' => 'fail', 'stories' => []})
      @deploy = Deploy.new
    end

    def with_versions(current, written)
      original_version = FlashFlow::VERSION
      FlashFlow.send(:remove_const, :VERSION)
      FlashFlow.const_set(:VERSION, current)
      data.expect(:version, written)
      yield
      data.verify
      FlashFlow.send(:remove_const, :VERSION)
      FlashFlow.const_set(:VERSION, original_version)
    end

    def test_version_is_nil
      with_versions('1.1.1', nil) do
        assert_nil(@deploy.check_version)
      end
    end

    def test_check_version_greater
      with_versions('2.0.0', '1.1.1') do
        assert_nil(@deploy.check_version)
      end

      with_versions('1.2.0', '1.1.1') do
        assert_nil(@deploy.check_version)
      end
    end

    def test_check_version_less_raises
      with_versions('1.1.1', '2.1.0') do
        assert_raises(RuntimeError) { @deploy.check_version }
      end

      with_versions('1.2.0', '2.1.0') do
        assert_raises(RuntimeError) { @deploy.check_version }
      end
    end

    def test_check_version_equal

    end

    def test_print_errors_with_no_errors
      data.expect(:failures, {})
      assert_equal(@deploy.format_errors, 'Success!')
    end

    def test_print_errors_when_current_branch_cant_merge
      data.expect(:failures, {'origin/pushing_branch' => @branch})
      @branch.fail!('some_random_sha')

      current_branch_error = "\nERROR: Your branch did not merge to test_acceptance. Run the following commands to fix the merge conflict and then re-run this script:\n\n  git checkout some_random_sha\n  git merge pushing_branch\n  # Resolve the conflicts\n  git add <conflicted files>\n  git commit --no-edit"

      @deploy.instance_variable_get('@git'.to_sym).stub(:working_branch, 'pushing_branch') do
        assert_equal(current_branch_error, @deploy.format_errors)
      end
    end

    def test_print_errors_when_another_branch_cant_merge
      data.expect(:failures, {'origin/pushing_branch' => @branch})

      other_branch_error = "WARNING: Unable to merge branch origin/pushing_branch to test_acceptance due to conflicts."

      assert_equal(@deploy.format_errors, other_branch_error)
    end

    def test_check_out_to_working_branch
      @deploy.stub(:check_repo, true) do
        Lock::Base.stub_any_instance(:with_lock, -> { raise Lock::Error }) do
          assert_output(/Failure!/) { @deploy.run }
        end
      end
    end

    def test_deleted_branch
      data.expect(:mark_deleted, true, [@branch])

      notifier.expect(:deleted_branch, true, [@branch])

      merger.expect(:do_merge, :deleted, [ false ])

      BranchMerger.stub(:new, merger) do
        @deploy.git_merge(@branch, false)
      end

      notifier.verify
      data.verify
      merger.verify
    end

    def test_merge_conflict
      data.expect(:mark_failure, true, [@branch, 'some_sha'])

      notifier.expect(:merge_conflict, true, [@branch])

      merger
          .expect(:do_merge, :conflict, [ false ])
          .expect(:conflict_sha, 'some_sha')

      BranchMerger.stub(:new, merger) do
        @deploy.git_merge(@branch, false)
      end

      notifier.verify
      data.verify
      merger.verify
    end

    def test_successful_merge
      data.expect(:mark_success, true, [@branch])
      data.expect(:set_resolutions, true, [ @branch, { 'filename' => ["resolution_sha"] } ])

      merger.
          expect(:do_merge, :success, [ false ]).
          expect(:sha, 'sha').
          expect(:resolutions, { 'filename' => ["resolution_sha"] })

      BranchMerger.stub(:new, merger) do
        @deploy.git_merge(@branch, false)
      end

      data.verify
      merger.verify
      assert_equal(@branch.sha, 'sha')
    end

    def test_ignore_pushing_master_or_acceptance
      ['test_master', 'test_acceptance'].each do |branch|
        @deploy.instance_variable_get('@git'.to_sym).stub(:working_branch, branch) do
          refute(@deploy.open_pull_request)
        end
      end
    end

    private

    def merger
      @merger ||= Minitest::Mock.new
    end

    def notifier
      return @notifier if @notifier

      @notifier = Minitest::Mock.new
      @deploy.instance_variable_set('@notifier'.to_sym, @notifier)
    end

    def data
      return @data if @data

      @data = Minitest::Mock.new
      @deploy.instance_variable_set('@data'.to_sym, @data)
    end

  end
end
