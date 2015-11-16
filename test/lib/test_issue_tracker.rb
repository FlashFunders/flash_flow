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
        def story_deployable?(story_id); "deployable: #{story_id}"; end
        def story_link(story_id); "link: #{story_id}"; end
        def story_title(story_id); "title: #{story_id}"; end
        def release_keys(story_id); "release_keys: #{story_id}"; end
        def stories_for_release(release_keys); "release stories: #{release_keys}"; end
      end

      def test_issue_tracker_class_not_set
        empty_issue_tracker = IssueTracker::Base.new
        issue_tracker.stub(:git, true) do
          issue_tracker.stub(:get_branches, true) do
            assert_nil(empty_issue_tracker.stories_pushed)
            assert_nil(empty_issue_tracker.stories_delivered)
            assert_nil(empty_issue_tracker.production_deploy)
            assert_nil(empty_issue_tracker.story_deployable?('123'))
            assert_nil(empty_issue_tracker.story_link('123'))
            assert_nil(empty_issue_tracker.story_title('123'))
            assert_nil(empty_issue_tracker.release_keys('123'))
            assert_nil(empty_issue_tracker.stories_for_release('release'))
          end
        end
      end

      def test_issue_tracker_class_set
        issue_tracker.stub(:git, true) do
          issue_tracker.stub(:get_branches, true) do
            assert_equal(FakeIssueTracker.new.stories_pushed, issue_tracker.stories_pushed)
            assert_equal(FakeIssueTracker.new.stories_delivered, issue_tracker.stories_delivered)
            assert_equal(FakeIssueTracker.new.production_deploy, issue_tracker.production_deploy)
            assert_equal(FakeIssueTracker.new.story_deployable?('123'), issue_tracker.story_deployable?('123'))
            assert_equal(FakeIssueTracker.new.story_link('123'), issue_tracker.story_link('123'))
            assert_equal(FakeIssueTracker.new.story_title('123'), issue_tracker.story_title('123'))
            assert_equal(FakeIssueTracker.new.release_keys('123'), issue_tracker.release_keys('123'))
            assert_equal(FakeIssueTracker.new.stories_for_release('release'), issue_tracker.stories_for_release('release'))
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
