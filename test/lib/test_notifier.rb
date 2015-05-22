require 'minitest_helper'
require 'flash_flow/notifier'

module FlashFlow
  module Notifier
    class TestBase < Minitest::Test

      class FakeNotifier
        def initialize(_=nil); end

        def merge_conflict(_=nil); 'merge conflict';end
        def deleted_branch(_=nil); 'deleted_branch';end
      end

      def test_notifier_class_not_set
        assert_nil(Notifier::Base.new.merge_conflict(nil))
        assert_nil(Notifier::Base.new.deleted_branch(nil))
      end

      def test_notifier_class_set
        assert_equal(FakeNotifier.new.merge_conflict, notifier.merge_conflict(nil))
        assert_equal(FakeNotifier.new.deleted_branch, notifier.deleted_branch(nil))
      end

      private

      def notifier
        Notifier::Base
            .new('class' => {'name' => 'FlashFlow::Notifier::TestBase::FakeNotifier'})
      end
    end
  end
end
