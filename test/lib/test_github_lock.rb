require 'minitest_helper'
require 'byebug'

module FlashFlow

  class TestGithub < Minitest::Test

    class SomeFakeError < RuntimeError; end

    def setup
      @github = Github.new('org/fake_repo')
      @github_lock = GithubLock.new('org/fake_repo', @github)
    end

    def test_error_message_when_issue_opened
      @github.stub(:issue_open?, true) do
        @github.stub(:get_last_event, {actor: {login: 'anonymous'}, created_at: Time.now }) do
          assert_raises(FlashFlow::Lock::Error) do
            @github_lock.with_lock(1)
          end
        end
      end
    end

    def test_with_lock_closes_issue_no_matter_what
      @github.stub(:issue_open?, false) do
        @github.stub(:open_issue, true) do
          # This assertion implicitly means issue is surely closed
          exception = assert_raises(Octokit::Unauthorized) do
            @github_lock.with_lock(1) { raise SomeFakeError }
          end
        end
      end
    end
  end
end
