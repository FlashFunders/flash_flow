require 'minitest_helper'
require 'flash_flow/notifier'

module FlashFlow
  module Notifier
    class TestBase < Minitest::Test

      class FakeNotifier
        def initialize(_); end

        def merge_conflict(_); 'merge conflict';end
      end

      def test_notifier_class_not_set
        assert_nil(Notifier::Base.new.merge_conflict('whatever'))
      end

      def test_notifier_class_set
        assert_equal(FakeNotifier.new(nil).merge_conflict('whatever'),
                     Notifier::Base
                         .new('class' => {'name' => 'FlashFlow::Notifier::TestBase::FakeNotifier'})
                         .merge_conflict('whatever'))
      end
    end
  end
end
