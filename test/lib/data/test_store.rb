require 'minitest_helper'
require 'flash_flow/data/store'

module FlashFlow
  module Data
    class TestBranchInfoStore < Minitest::Test
      def sample_branches
        {
            'origin/branch 1' => {'branch' => 'branch 1', 'remote' => 'origin', 'status' => 'success', 'stories' => ['123']},
            'other_origin/branch 2' => {'branch' => 'branch 2', 'remote' => 'origin', 'status' => 'success', 'stories' => ['456']}
        }
      end

      def setup
        @mock_git = MockGit.new
        @mock_store = Minitest::Mock.new
        @collection = Collection.new({ 'origin' => 'the_origin_url' }, @mock_store)
        @branch = Branch.new('origin', 'the_origin_url', 'some_branch')
        @storage = Store.new('/dev/null', @mock_git)
      end

      def test_merge_when_old_is_empty
        @collection.mark_success(@branch)

        merged = @storage.merge({}, @collection.branches)
        assert_equal(['the_origin_url/some_branch'], merged.keys)
        assert(merged['the_origin_url/some_branch'].success?)
      end

      def test_merge_old_marks_old_branches
        @collection.mark_success(@branch)

        merged = @storage.merge(old_branches, @collection.branches)
        assert(merged['the_origin_url/some_old_branch'].unknown?)
      end

      def test_merge_old_adds_new_stories
        @collection.mark_success(@branch)
        @collection.add_story('origin', 'some_branch', '456')
        merged = @storage.merge(old_branches, @collection.branches)

        assert_equal(['222', '456'], merged['the_origin_url/some_branch'].stories)
      end

      def test_merge_old_uses_old_created_at
        @collection.add_to_merge('origin', 'some_old_branch')
        @collection.add_to_merge('origin', 'some_new_branch')
        merged = @storage.merge(old_branches, @collection.branches)

        assert_equal(old_branches['the_origin_url/some_branch'].created_at, merged['the_origin_url/some_branch'].created_at)
        # Assert the new branch is created_at within the last minute
        assert(merged['the_origin_url/some_new_branch'].created_at > (Time.now - 60))
      end

      def test_merge_old_uses_new_status
        @collection.mark_failure(old_branches['the_origin_url/some_branch'])
        merged = @storage.merge(old_branches, @collection.branches)

        assert(merged['the_origin_url/some_branch'].fail?)
      end

      def test_get
        @mock_git.stub(:read_file_from_merge_branch, JSON.pretty_generate(old_branches)) do
          assert_equal(@storage.get, old_branches)
        end
      end

      def test_write
        str = StringIO.new
        @storage.write(old_branches, str)

        assert_equal(str.string.strip, JSON.pretty_generate(old_branches).strip)
      end

      private # Helpers

      def old_branches
        @old_branches ||= {
            'the_origin_url/some_old_branch' => Branch.from_hash({'ref' => 'some_old_branch', 'remote_url' => 'the_origin_url', 'remote' => 'origin', 'created_at' => (Time.now - 3600), 'stories' => ['111']}),
            'the_origin_url/some_branch' => Branch.from_hash({'ref' => 'some_branch', 'remote_url' => 'the_origin_url', 'remote' => 'origin', 'status' => 'success', 'created_at' => (Time.now - 1800), 'stories' => ['222']})
        }
      end
    end

    class MockGit
      def read_file_from_merge_branch; end
      def add_and_commit(_,_,_=nil); end

      def in_merge_branch
        yield
      end
    end
  end
end
