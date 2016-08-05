require 'minitest_helper'
require 'flash_flow/merge'

module FlashFlow
  module Merge
    class TestReleaseGraph < Minitest::Test

      class FakeIssueTracker
        STORY_ID1 = '111'
        STORY_ID2 = '222'
        STORY_ID3 = '333'
        STORY_ID4 = '444'
        STORY_ID5 = '555'
        STORY_ID6 = '666'

        def release_keys(story_id)
          {
              STORY_ID1 => ['release1', 'release2'],
              STORY_ID2 => [],
              STORY_ID3 => ['release2'],
              STORY_ID4 => ['release3', 'release4'],
              STORY_ID5 => [],
              STORY_ID6 => ['release3'],
          }[story_id]
        end

        def stories_for_release(release_keys)
          hash = Hash.new([])
          hash['release1'] = [STORY_ID1]
          hash['release2'] = [STORY_ID1, STORY_ID3]

          hash[release_keys]
        end

      end

      BRANCH1 = Data::Branch.from_hash('ref' => 'branch1', 'stories' => ['111', '222'])
      BRANCH2 = Data::Branch.from_hash('ref' => 'branch2', 'stories' => ['333'])
      BRANCH3 = Data::Branch.from_hash('ref' => 'branch3', 'stories' => ['444', '555', '666'])

      ################
      ## Begin actual tests

      def setup
        @graph = ReleaseGraph.build([BRANCH1, BRANCH2, BRANCH3], FakeIssueTracker.new)
      end

      def test_connected_branches
        assert_equal(@graph.connected_branches(BRANCH1.ref), [BRANCH1, BRANCH2])
        assert_equal(@graph.connected_branches(BRANCH2.ref), [BRANCH1, BRANCH2])
        assert_equal(@graph.connected_branches(BRANCH3.ref), [BRANCH3])
      end

      def test_connected_stories
        assert_equal(@graph.connected_stories(BRANCH1.ref), ['111', '222', '333'])
        assert_equal(@graph.connected_stories(BRANCH2.ref), ['111', '222', '333'])
        assert_equal(@graph.connected_stories(BRANCH3.ref), ['444', '555', '666'])
      end

      def test_connected_releases
        assert_equal(@graph.connected_releases(BRANCH1.ref), ['release1', 'release2'])
        assert_equal(@graph.connected_releases(BRANCH2.ref), ['release1', 'release2'])
        assert_equal(@graph.connected_releases(BRANCH3.ref), ['release3', 'release4'])
      end

      def test_no_branches
        g = ReleaseGraph.build([], FakeIssueTracker.new)
        assert(g.connected_branches(BRANCH1.ref).empty?)
        assert(g.connected_stories(BRANCH1.ref).empty?)
        assert(g.connected_releases(BRANCH1.ref).empty?)
      end
    end
  end
end
