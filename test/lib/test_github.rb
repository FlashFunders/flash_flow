require 'minitest_helper'

module FlashFlow


  class TestGithub < Minitest::Test

    class SomeFakeError < RuntimeError; end

    def setup
      @github = Github.new('fake_repo')
      @octokit = Minitest::Mock.new
    end

    def test_cant_initialize_without_token
      val = ENV.delete('GH_TOKEN')
      assert_raises(RuntimeError) do
        Github.new('fake_repo')
      end
      ENV['GH_TOKEN'] = val
    end

    def test_with_lock_closes_issue_no_matter_what
      @github.stub(:octokit, @octokit) do
        @octokit.expect(:close_issue, true, ['fake_repo', 1])

        @github.stub(:open_issue, true) do
          begin
            @github.with_lock(1) do
              raise SomeFakeError
            end
          rescue SomeFakeError
          end
        end
      end
    end

  end
end
