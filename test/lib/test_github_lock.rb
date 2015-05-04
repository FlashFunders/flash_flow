require 'minitest_helper'
require 'minitest/stub_any_instance'

module FlashFlow

  class TestGithub < Minitest::Test

    class SomeFakeError < RuntimeError; end

    def setup
      @github_lock = GithubLock.new('org/fake_repo')
    end

    def test_error_message_when_issue_opened
      Github.stub_any_instance(:issue_open?, true) do
        Github.stub_any_instance(:get_last_event, {actor: {login: 'anonymous'}, created_at: Time.now }) do
          assert_raises(FlashFlow::Lock::Error) do
            @github_lock.with_lock(1)
          end
        end
      end
    end

    def test_with_lock_closes_issue_no_matter_what
      Github.stub_any_instance(:issue_open?, false) do
        Github.stub_any_instance(:open_issue, true) do
          # This assertion implicitly means issue is surely closed
          exception = assert_raises(Octokit::Unauthorized) do
            @github_lock.with_lock(1) { raise SomeFakeError }
          end
        end
      end
    end
  end
end
