require 'minitest_helper'
require 'flash_flow/issue_tracker/pivotal'
require 'flash_flow/time_helper'

module FlashFlow
  module IssueTracker
    class TestPivotal < Minitest::Test
      include TimeHelper

      def setup
        @project_mock = MiniTest::Mock.new
        @stories = MiniTest::Mock.new
      end

      def test_stories_pushed_only_marks_success_branches
        stub_tracker_gem(@project_mock) do
          [[0,'111'],[1,'222']].each do |branch, story|
            mock_find(nil, story)
            git = mock_working_branch(branch)

            Pivotal.new(sample_branches, git).stories_pushed
            @stories.verify
          end
        end
      end

      def test_stories_delivered_gets_success_and_removed_stories
        stub_tracker_gem(@project_mock) do
          mock_find(nil, '111')
          mock_find(nil, '222')
          mock_find(nil, '333')
          mock_find(nil, '555')

          Pivotal.new(sample_branches, nil).stories_delivered
          @stories.verify
        end
      end

      def test_stories_delivered_only_delivers_finished_stories
        stub_tracker_gem(@project_mock) do
          story1_mock = MiniTest::Mock.new
                            .expect(:id, '111')
                            .expect(:current_state, 'finished')
                            .expect(:current_state=, true, ['delivered'])
                            .expect(:update, true)
          story2_mock = MiniTest::Mock.new
                            .expect(:id, '222')
                            .expect(:current_state, 'delivered')
          story3_mock = MiniTest::Mock.new
                            .expect(:id, '333')
                            .expect(:current_state, 'fail')
          story4_mock = MiniTest::Mock.new
                            .expect(:id, '555')
                            .expect(:current_state, 'removed')
          mock_find(story1_mock)
          mock_find(story2_mock)
          mock_find(story3_mock)
          mock_find(story4_mock)

          Pivotal.new(sample_branches, nil).stories_delivered
          story1_mock.verify
          story2_mock.verify
          story3_mock.verify
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

          [[0,story1_mock],[1,story2_mock]].each do |branch, story|
            git = mock_working_branch(branch)

            Pivotal.new(sample_branches, git).stories_pushed
            story.verify
          end
        end
      end

      def test_stories_pushed_only_finishes_stories_of_current_branch
        stub_tracker_gem(@project_mock) do
          story1_mock = MiniTest::Mock.new
                            .expect(:id, '111')
                            .expect(:current_state, 'started')
                            .expect(:current_state=, true, ['finished'])
                            .expect(:update, true)
          story2_mock = MiniTest::Mock.new
                            .expect(:id, '222')
          mock_find(story1_mock)
          mock_find(story2_mock)

          git = mock_working_branch(0)

          Pivotal.new(sample_branches, git).stories_pushed
          story1_mock.verify
          story2_mock.verify
        end
      end

      def test_production_deploy_only_comments_on_shipped_branches
        stub_tracker_gem(@project_mock) do
          mock_find(nil, '111')

          Pivotal.new(sample_branches, mock_git).production_deploy
          @stories.verify
        end
      end

      def test_production_deploy_comments
        shipped_text = with_time_zone("US/Pacific") { Time.now.strftime("Shipped to production on %m/%d/%Y at %H:%M") }
        fake_notes = Minitest::Mock.new
                          .expect(:all, [mock_comment('Some random comment'), mock_comment('Some other random comment')])
                          .expect(:create, true, [{ text: shipped_text }])
        story_mock = MiniTest::Mock.new
                          .expect(:id, '111')
                          .expect(:notes, fake_notes)
                          .expect(:notes, fake_notes)

        stub_tracker_gem(@project_mock) do
          mock_find(story_mock)

          Pivotal.new(sample_branches, mock_git, {'timezone' => "US/Pacific"}).production_deploy
        end

        story_mock.verify
        fake_notes.verify
      end

      def test_production_deploy_only_comments_if_no_existing_comment
        fake_notes = Minitest::Mock.new
                          .expect(:all, [mock_comment('Some random comment'), mock_comment('Shipped to production on')])
        story_mock = MiniTest::Mock.new
                         .expect(:id, '111')
                         .expect(:notes, fake_notes)

        stub_tracker_gem(@project_mock) do
          mock_find(story_mock)

          Pivotal.new(sample_branches, mock_git).production_deploy
        end

        story_mock.verify
        fake_notes.verify
      end

      def test_list_release_notes_with_time_scope
        time = Time.now
        time -= time.sec
        time_now = time.strftime("%m/%d/%Y at %H:%M")
        fake_notes = Minitest::Mock.new
                      .expect(:all, [mock_comment('Some random comment'), mock_comment("Shipped to production on #{time_now}")])
        story_mock = MiniTest::Mock.new
                      .expect(:id, '111')
                      .expect(:name, 'fake_name')
                      .expect(:notes, fake_notes)
        fake_file = MiniTest::Mock.new
                      .expect(:puts, nil, ["PT#111 fake_name (#{time})"])

        stub_tracker_gem(@project_mock) do
          pivotal = Pivotal.new(sample_branches, mock_git)
          pivotal.stub(:done_and_current_stories, [story_mock]) do
            pivotal.release_notes(24, fake_file)
          end
        end

        story_mock.verify
        fake_notes.verify
        fake_file.verify
      end

      def test_story_deployable
        story_mock = MiniTest::Mock.new
                         .expect(:id, '111')
                         .expect(:current_state, 'accepted')

        stub_tracker_gem(@project_mock) do
          mock_find(story_mock)
          assert(Pivotal.new(sample_branches, mock_git).story_deployable?('111'))
        end
      end

      def test_story_deployable_false
        story_mock = MiniTest::Mock.new
                         .expect(:id, '111')
                         .expect(:current_state, 'delivered')

        stub_tracker_gem(@project_mock) do
          mock_find(story_mock)
          refute(Pivotal.new(sample_branches, mock_git).story_deployable?('111'))
        end
      end

      def test_story_link
        story_mock = MiniTest::Mock.new
                         .expect(:id, '111')
                         .expect(:url, 'http://some_url')

        stub_tracker_gem(@project_mock) do
          mock_find(story_mock)
          assert_equal('http://some_url', Pivotal.new(sample_branches, mock_git).story_link('111'))
        end
      end

      def test_story_title
        story_mock = MiniTest::Mock.new
                         .expect(:id, '111')
                         .expect(:name, 'Some Title')

        stub_tracker_gem(@project_mock) do
          mock_find(story_mock)
          assert_equal('Some Title', Pivotal.new(sample_branches, mock_git).story_title('111'))
        end
      end

      def test_release_keys
        story_mock = MiniTest::Mock.new
                         .expect(:id, '111')
                         .expect(:labels, 'Release-1, Not-A-Release-2, release-3')
                         .expect(:labels, 'Release-1, Not-A-Release-2, release-3')

        stub_tracker_gem(@project_mock) do
          mock_find(story_mock)
          assert_equal(['Release-1', 'release-3'], Pivotal.new(sample_branches, mock_git, 'release_label_prefix' => 'release').release_keys('111'))
        end
      end

      def test_stories_for_release
        story_mock = MiniTest::Mock.new
                         .expect(:id, '111')

        stub_tracker_gem(@project_mock) do
          mock_all([story_mock], label: 'release')
          assert_equal(['111'], Pivotal.new(sample_branches, mock_git).stories_for_release('release'))
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

      def mock_git
        Minitest::Mock.new
            .expect(:master_branch_contains?, true, [sample_branches[0].sha])
            .expect(:master_branch_contains?, false, [sample_branches[1].sha])
            .expect(:master_branch_contains?, false, [sample_branches[2].sha])
            .expect(:master_branch_contains?, false, [sample_branches[3].sha])
            .expect(:master_branch_contains?, false, [sample_branches[4].sha])
      end

      def mock_working_branch(index)
        git = Minitest::Mock.new
        5.times { git.expect(:working_branch, sample_branches[index].ref) }
        git
      end

      def mock_comment(comment)
        Minitest::Mock.new.expect(:text, comment)
      end

      def mock_find(story, story_id=nil)
        story_id ||= story.id
        @project_mock.expect(:stories, @stories.expect(:find, story, [story_id]))
      end

      def mock_all(stories, opts={})
        @project_mock.expect(:stories, @stories.expect(:all, stories, [opts]))
      end

      def sample_branches
        @sample_branches ||= [Data::Branch.from_hash({'ref' => 'branch1', 'remote' => 'origin', 'sha' => 'sha1', 'status' => 'success', 'created_at' => (Time.now - 3600), 'stories' => ['111']}),
            Data::Branch.from_hash({'ref' => 'branch2', 'remote' => 'origin', 'sha' => 'sha2', 'status' => 'success', 'created_at' => (Time.now - 1800), 'stories' => ['222']}),
            Data::Branch.from_hash({'ref' => 'branch3', 'remote' => 'origin', 'sha' => 'sha3', 'status' => 'fail', 'created_at' => (Time.now - 1800), 'stories' => ['333']}),
            Data::Branch.from_hash({'ref' => 'branch4', 'remote' => 'origin', 'sha' => 'sha4', 'status' => nil, 'created_at' => (Time.now - 1800), 'stories' => ['444']}),
            Data::Branch.from_hash({'ref' => 'branch5', 'remote' => 'origin', 'sha' => 'sha5', 'status' => 'removed', 'created_at' => (Time.now - 1800), 'stories' => ['555']})
        ]
      end
    end
  end
end
