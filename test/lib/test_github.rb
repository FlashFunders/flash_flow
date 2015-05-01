require 'minitest_helper'

module FlashFlow

  class TestGithub < Minitest::Test

    class SomeFakeError < RuntimeError; end

    def setup
      @github = Github.new('org/fake_repo')
      @github_lock = GithubLock.new('org/fake_repo', @github)
      @octokit = Minitest::Mock.new
    end

    def test_cant_initialize_without_token
      val = ENV.delete('GH_TOKEN')
      assert_raises(RuntimeError) do
        Github.new('org/fake_repo')
      end
      ENV['GH_TOKEN'] = val
    end

    def test_error_message_when_issue_opened
      @github.stub(:octokit, @octokit) do
        @github.stub(:issue_open?, true) do
          @github.stub(:get_last_event, {actor: {login: 'anonymous'}, created_at: Time.now }) do
            assert_raises(FlashFlow::Lock::Error) do
              @github_lock.with_lock(1)
            end
          end
        end
      end
    end

    def test_with_lock_closes_issue_no_matter_what
      @octokit.expect(:close_issue, true, ['org/fake_repo', 1])

      @github.stub(:octokit, @octokit) do
        @github.stub(:issue_open?, false) do
          @github.stub(:open_issue, true) do
            begin
              @github_lock.with_lock(1) do
                raise SomeFakeError
              end
            rescue SomeFakeError
            end
          end
        end
      end
    end
  end
end
