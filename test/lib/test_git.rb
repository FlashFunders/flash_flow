require 'minitest_helper'

module FlashFlow
  class TestGit < Minitest::Test
    def setup
      @git_args = {
          'merge_branch' => 'acceptance',
          'remote' => 'origin',
          'master_branch' => 'master',
          'use_rerere' => true
      }
      @cmd_runner = setup_cmd_runner
    end

    def test_initialize_rerere_checks_flag
      @git_args['use_rerere'] = false

      instance.initialize_rerere

      @cmd_runner.verify
    end

    def test_initialize_rerere_runs_commands
      @cmd_runner.expect(:run, true, ['mkdir .git/rr-cache'])
      @cmd_runner.expect(:run, true, ['cp -R rr-cache/* .git/rr-cache/'])

      instance.initialize_rerere
      @cmd_runner.verify
    end

    def test_commit_rerere_checks_flag
      @git_args['use_rerere'] = false
      instance.commit_rerere([])

      @cmd_runner.verify
    end

    def test_commit_rerere_runs_commands
      @cmd_runner.expect(:run, true, ['mkdir rr-cache'])
      @cmd_runner.expect(:run, true, ['rm -rf rr-cache/*'])
      @cmd_runner.expect(:run, true, ['cp -R .git/rr-cache/xyz rr-cache/'])
      @cmd_runner.expect(:run, true, ['cp -R .git/rr-cache/abc rr-cache/'])
      @cmd_runner.expect(:run, true, ['git add rr-cache/', {}])
      @cmd_runner.expect(:run, true, ["git commit -m 'Update rr-cache'", {}])

      instance.commit_rerere(['xyz', 'abc'])
      @cmd_runner.verify
    end

    def test_read_file_from_merge_branch
      @cmd_runner.expect(:run, true, ["git show origin/acceptance:SomeFilename.txt", log: CmdRunner::LOG_CMD])
      @cmd_runner.expect(:last_stdout, 'some_json', [])
      @git_args['use_rerere'] = false

      assert_equal(instance.read_file_from_merge_branch('SomeFilename.txt'), 'some_json')
      @cmd_runner.verify
    end

  private
    def instance
      CmdRunner.stub(:new, @cmd_runner) do
        _instance = Git.new(@git_args)
      end
    end

    def setup_cmd_runner
      cmd_runner = Minitest::Mock.new
      cmd_runner.expect(:run, true, ['git rev-parse --abbrev-ref HEAD', {}])
      cmd_runner.expect(:last_stdout, 'current_branch', [])
      cmd_runner.expect(:dir, '.', [])
      cmd_runner
    end
  end
end
