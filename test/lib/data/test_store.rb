require 'minitest_helper'
require 'flash_flow/data/store'

module FlashFlow
  module Data
    class TestStore < Minitest::Test
      def sample_branches
        {
            'origin/branch 1' => {'branch' => 'branch 1', 'remote' => 'origin', 'status' => 'success', 'stories' => ['123']},
            'other_origin/branch 2' => {'branch' => 'branch 2', 'remote' => 'origin', 'status' => 'success', 'stories' => ['456']}
        }
      end

      def setup
        @mock_git = MockGit.new
        @collection = Collection.new({ 'origin' => 'the_origin_url' })
        @branch = Branch.new('origin', 'the_origin_url', 'some_branch')
        @storage = Store.new('/dev/null', @mock_git)
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
            'the_origin_url/some_old_branch' => {'ref' => 'some_old_branch', 'remote_url' => 'the_origin_url', 'remote' => 'origin', 'created_at' => (Time.now - 3600).to_s, 'stories' => ['111']},
            'the_origin_url/some_branch' => {'ref' => 'some_branch', 'remote_url' => 'the_origin_url', 'remote' => 'origin', 'status' => 'success', 'created_at' => (Time.now - 1800).to_s, 'stories' => ['222']}
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
