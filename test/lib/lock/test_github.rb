require 'minitest_helper'
require 'minitest/stub_any_instance'

module FlashFlow
  module Lock
    class TestGithub < Minitest::Test
      class SomeFakeError < RuntimeError;
      end

      def setup
        @lock = Lock::Github.new(params)
      end

      def test_raises_without_required_params
        config = params.select { |k, _| k != 'token' }
        assert_raises(Lock::Error) { Lock::Github.new(config) }

        config = params.select { |k, _| k != 'repo' }
        assert_raises(Lock::Error) { Lock::Github.new(config) }

        config = params.select { |k, _| k != 'issue_id' }
        assert_raises(Lock::Error) { Lock::Github.new(config) }
      end

      def test_error_message_when_issue_opened
        @lock.stub(:issue_open?, true) do
          @lock.stub(:get_last_event, {actor: {login: 'anonymous'}, created_at: Time.now}) do
            assert_raises(FlashFlow::Lock::Error) do
              @lock.with_lock
            end
          end
        end
      end

      def test_with_lock_calls_the_block
        my_mock = Minitest::Mock.new.expect(:block_call, true).expect(:close_issue, true)

        @lock.stub(:issue_open?, false) do
          @lock.stub(:open_issue, nil) do
            @lock.stub(:close_issue, -> { my_mock.close_issue }) do
              @lock.with_lock { my_mock.block_call }
              my_mock.verify
            end
          end
        end
      end

      def test_with_lock_closes_issue_no_matter_what
        my_mock = Minitest::Mock.new.expect(:some_method, true)

        @lock.stub(:issue_open?, false) do
          @lock.stub(:open_issue, nil) do
            @lock.stub(:close_issue, -> { my_mock.some_method }) do
              assert_raises(SomeFakeError) do
                @lock.with_lock { raise SomeFakeError }
                my_mock.verify
              end
            end
          end
        end
      end

      private

      def params
        {'token' => '1234567890', 'repo' => 'f/f', 'issue_id' => '123'}
      end
    end
  end
end
