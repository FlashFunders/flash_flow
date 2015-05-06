require 'minitest_helper'

module FlashFlow
  class TestGit < Minitest::Test
    def setup
      @cmd_runner = setup_cmd_runner
      @instance = Git.new(@cmd_runner, 'origin', 'acceptance', 'master', true)
    end

    def test_initialize_rerere_checks_flag
      cmd_runner = setup_cmd_runner
      instance = Git.new(cmd_runner, 'origin', 'acceptance', 'master', false)
      instance.initialize_rerere

      cmd_runner.verify
    end

    def test_initialize_rerere_runs_commands
      @cmd_runner.expect(:run, true, ['mkdir .git/rr-cache'])
      @cmd_runner.expect(:run, true, ['cp -R rr-cache/* .git/rr-cache/'])

      @instance.initialize_rerere
      @cmd_runner.verify
    end

    def test_commit_rerere_checks_flag
      cmd_runner = setup_cmd_runner
      instance = Git.new(cmd_runner, 'origin', 'acceptance', 'master', false)
      instance.commit_rerere

      cmd_runner.verify
    end

    def test_commit_rerere_runs_commands
      @cmd_runner.expect(:run, true, ['mkdir rr-cache'])
      @cmd_runner.expect(:run, true, ['cp -R .git/rr-cache/* rr-cache/'])
      @cmd_runner.expect(:run, true, ['git add rr-cache/'])
      @cmd_runner.expect(:run, true, ["git commit -m 'Update rr-cache'"])

      @instance.commit_rerere
      @cmd_runner.verify
    end

  private
    def setup_cmd_runner
      cmd_runner = Minitest::Mock.new
      cmd_runner.expect(:run, true, ['git rev-parse --abbrev-ref HEAD'])
      cmd_runner.expect(:last_stdout, 'current_branch', [])
      cmd_runner
    end
  end
end
