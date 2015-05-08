require 'minitest_helper'
require 'flash_flow/issue_tracker'

module FlashFlow
  class TestIssueTracker < Minitest::Test

    class FakeIssueTracker
      def initialize(*args); end
      def stories_pushed; 'pushed!'; end
    end

    def setup
      reset_config!
    end

    def test_issue_tracker_class_not_set
      config!(repo: 'does not matter', issue_tracker: nil)
      assert_nil(IssueTracker::Base.new.stories_pushed)
    end

    def test_issue_tracker_class_set
      config!(repo: 'does not matter', issue_tracker: { 'class' => 'FlashFlow::TestIssueTracker::FakeIssueTracker' })

      assert_equal(FakeIssueTracker.new.stories_pushed, IssueTracker::Base.new.stories_pushed)
    end
  end
end
