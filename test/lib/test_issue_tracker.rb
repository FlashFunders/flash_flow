require 'minitest_helper'
require 'flash_flow/issue_tracker'

module FlashFlow
  class TestIssueTracker < Minitest::Test

    class FakeIssueTracker
      def initialize(*args); end
      def stories_pushed; 'pushed!'; end
      def production_deploy; 'deployed!'; end
      def stories_delivered; 'delivered!'; end
    end

    def setup
      reset_config!
    end

    def test_issue_tracker_class_not_set
      config!(repo: 'does not matter', issue_tracker: nil)
      assert_nil(IssueTracker::Base.new.stories_pushed)
      assert_nil(IssueTracker::Base.new.stories_delivered)
      assert_nil(IssueTracker::Base.new.production_deploy)
    end

    def test_issue_tracker_class_set
      config!(repo: 'does not matter', issue_tracker: { 'class' => 'FlashFlow::TestIssueTracker::FakeIssueTracker' })

      assert_equal(FakeIssueTracker.new.stories_pushed, IssueTracker::Base.new.stories_pushed)
      assert_equal(FakeIssueTracker.new.stories_delivered, IssueTracker::Base.new.stories_delivered)
      assert_equal(FakeIssueTracker.new.production_deploy, IssueTracker::Base.new.production_deploy)
    end
  end
end
