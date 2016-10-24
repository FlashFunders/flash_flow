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

      def test_error_message_when_issue_locked
        @lock.stub(:actor, 'actor') do
          @lock.stub(:issue_locked?, true) do
            @lock.stub(:get_lock_labels, {name: @lock.send(:locked_label)}) do
              assert_raises(FlashFlow::Lock::Error) do
                @lock.with_lock
              end
            end
          end
        end
      end

      def test_with_lock_calls_the_block
        my_mock = Minitest::Mock.new.expect(:block_call, true).expect(:unlock_issue, true)

        @lock.stub(:issue_locked?, false) do
          @lock.stub(:lock_issue, nil) do
            @lock.stub(:unlock_issue, -> { my_mock.unlock_issue }) do
              @lock.with_lock { my_mock.block_call }
              my_mock.verify
            end
          end
        end
      end

      def test_with_unlock_issue_no_matter_what
        my_mock = Minitest::Mock.new
          .expect(:some_method, true)
          .expect(:actor, 'actor')

        @lock.stub(:issue_locked?, false) do
          @lock.stub(:lock_issue, nil) do
            @lock.stub(:unlock_issue, -> { my_mock.some_method }) do
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
