require 'minitest_helper'

module FlashFlow
  module Data
    class TestGithub < Minitest::Test

      class SomeFakeError < RuntimeError; end

      def setup
        # @github = Github.new('fake_repo')
        # @octokit = Minitest::Mock.new
      end

      def test_cant_initialize_without_token
        # val = ENV.delete('GH_TOKEN')
        # assert_raises(RuntimeError) do
        #   Github.new('fake_repo')
        # end
        # ENV['GH_TOKEN'] = val
      end
    end
  end
end
