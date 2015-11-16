require 'minitest_helper'
require 'flash_flow/merge_master'

module FlashFlow
  module MergeMaster
    class TestStatus < Minitest::Test

      class TestableMergeMaster < Status
        def initialize;
        end

        attr_accessor :issue_tracker, :collection

      end

      class FakeIssueTracker
        STORY_ID1 = '111'
        STORY_ID2 = '222'
        STORY_ID3 = '333'
        STORY_ID4 = '444'
        STORY_ID5 = '555'
        STORY_ID6 = '666'

        def story_deployable?(story_id)
          {
              STORY_ID1 => true,
              STORY_ID2 => true,
              STORY_ID3 => true,
              STORY_ID4 => true,
              STORY_ID5 => false,
              STORY_ID6 => true,
          }[story_id]
        end

        def release_keys(story_id)
          {
              STORY_ID1 => ['release1', 'release2'],
              STORY_ID2 => [],
              STORY_ID3 => ['release2'],
              STORY_ID4 => ['release3', 'release4'],
              STORY_ID5 => [],
              STORY_ID6 => ['release4'],
          }[story_id]
        end

        def stories_for_release(release_keys)
          hash = Hash.new([])
          hash['release1'] = [STORY_ID1]
          hash['release2'] = [STORY_ID1, STORY_ID3]

          hash[release_keys]
        end

        def story_link(story_id)
          ; "link: #{story_id}";
        end

        def story_title(story_id)
          ; "title: #{story_id}";
        end
      end

      class FakeCollection
        BRANCH1 = Data::Branch.from_hash('ref' => 'branch1', 'stories' => ['111', '222'])
        BRANCH2 = Data::Branch.from_hash('ref' => 'branch2', 'stories' => ['333'])
        BRANCH3 = Data::Branch.from_hash('ref' => 'branch3', 'stories' => ['444', '555', '666'])

        def branch_link(branch)
          return "link-#{branch.ref}"
        end

        def can_ship?(branch)
          {
              BRANCH1 => true,
              BRANCH2 => true,
              BRANCH3 => false,
          }[branch]
        end

        def current_branches
          [BRANCH1, BRANCH2, BRANCH3]
        end
      end

      ################
      ## Begin actual tests

      def setup
        @merge_master = TestableMergeMaster.new
        @merge_master.issue_tracker = FakeIssueTracker.new
        @merge_master.collection = FakeCollection.new
      end

      def test_shippable_branch
        branches = @merge_master.branches
        branch1 = branches[FakeCollection::BRANCH1]
        branch2 = branches[FakeCollection::BRANCH2]

        assert(branch1[:stories].all? { |s| @merge_master.stories[s][:can_ship?] })
        assert_equal(branch1[:stories], branch2[:stories])
        assert(branch1[:shippable?])
      end

      def test_not_shippable_branch
        branches = @merge_master.branches
        branch3 = branches[FakeCollection::BRANCH3]

        assert_equal(branch3[:stories].map { |s| @merge_master.stories[s][:can_ship?] }, [true, false, true])
        refute(branch3[:shippable?])
      end

      private

      def find_branch(status_list, branch)
        status_list[branch]
      end
    end
  end
end
