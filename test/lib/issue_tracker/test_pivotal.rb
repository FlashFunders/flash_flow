require 'minitest_helper'
require 'flash_flow/issue_tracker/pivotal'

module FlashFlow
  module IssueTracker
    class TestPivotal < Minitest::Test
      def setup
        @project_mock = MiniTest::Mock.new
        @stories = MiniTest::Mock.new
      end

      def test_stories_pushed_only_marks_success_branches
        stub_tracker_gem(@project_mock) do
          mock_find(nil, '111')
          mock_find(nil, '222')

          Pivotal.new(sample_branches).stories_pushed
          @stories.verify
        end
      end

      def test_stories_pushed_only_finishes_started_stories
        stub_tracker_gem(@project_mock) do
          story1_mock = MiniTest::Mock.new
                            .expect(:id, '111')
                            .expect(:current_state, 'started')
                            .expect(:current_state=, true, ['finished'])
                            .expect(:update, true)
          story2_mock = MiniTest::Mock.new
                            .expect(:id, '222')
                            .expect(:current_state, 'finished')
          mock_find(story1_mock)
          mock_find(story2_mock)

          Pivotal.new(sample_branches).stories_pushed
          story1_mock.verify
          story2_mock.verify
        end
      end

      private

      def stub_tracker_gem(project)
        PivotalTracker::Client.stub(:token=, true) do
          PivotalTracker::Client.stub(:use_ssl=, true) do
            PivotalTracker::Project.stub(:find, project) do
              yield
            end
          end
        end
      end

      def mock_find(story, story_id=nil)
        story_id ||= story.id
        @project_mock.expect(:stories, @stories.expect(:find, story, [story_id]))
      end

      def sample_branches
        @sample_branches ||= {
            'origin/branch1' => Branch::Base.from_hash({'branch' => 'branch1', 'remote' => 'origin', 'status' => 'success', 'created_at' => (Time.now - 3600), 'stories' => ['111']}),
            'origin/branch2' => Branch::Base.from_hash({'branch' => 'branch2', 'remote' => 'origin', 'status' => 'success', 'created_at' => (Time.now - 1800), 'stories' => ['222']}),
            'origin/branch3' => Branch::Base.from_hash({'branch' => 'branch3', 'remote' => 'origin', 'status' => 'fail', 'created_at' => (Time.now - 1800), 'stories' => ['333']}),
            'origin/branch4' => Branch::Base.from_hash({'branch' => 'branch4', 'remote' => 'origin', 'status' => nil, 'created_at' => (Time.now - 1800), 'stories' => ['444']})

        }
      end
    end
  end
end
