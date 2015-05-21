require 'minitest_helper'
require 'flash_flow/issue_tracker'

module FlashFlow
  module IssueTracker
    class TestBase < Minitest::Test

      class FakeIssueTracker
        def initialize(*args); end
        def stories_pushed; 'pushed!'; end
        def production_deploy; 'deployed!'; end
        def stories_delivered; 'delivered!'; end
      end

      def test_issue_tracker_class_not_set
        empty_issue_tracker = IssueTracker::Base.new
        issue_tracker.stub(:git, true) do
          issue_tracker.stub(:get_branches, true) do
            assert_nil(empty_issue_tracker.stories_pushed)
            assert_nil(empty_issue_tracker.stories_delivered)
            assert_nil(empty_issue_tracker.production_deploy)
          end
        end
      end

      def test_issue_tracker_class_set
        issue_tracker.stub(:git, true) do
          issue_tracker.stub(:get_branches, true) do
            assert_equal(FakeIssueTracker.new.stories_pushed, issue_tracker.stories_pushed)
            assert_equal(FakeIssueTracker.new.stories_delivered, issue_tracker.stories_delivered)
            assert_equal(FakeIssueTracker.new.production_deploy, issue_tracker.production_deploy)
          end
        end
      end

      private

      def issue_tracker
        @issue_tracker ||= IssueTracker::Base.new({ 'class' => { 'name' => 'FlashFlow::IssueTracker::TestBase::FakeIssueTracker' }})
      end
    end
  end
end
