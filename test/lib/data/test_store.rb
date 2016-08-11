require 'minitest_helper'
require 'flash_flow/data/store'

module FlashFlow
  module Data
    class TestStore < Minitest::Test
      def setup
        @mock_git = MockGit.new
        @collection = Collection.new
        @branch = Branch.new('some_branch')
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

        assert_equal(str.string.strip, JSON.pretty_generate(sorted_branches).strip)
      end

      private # Helpers

      def old_branches
        @old_branches ||= {
            'version' => '1.0.0',
            'branches' => {
              'some_old_branch' => {'ref' => 'some_old_branch', 'created_at' => (Time.now - 3600).to_s, 'stories' => ['111']},
              'some_branch' => {'ref' => 'some_branch', 'status' => 'success', 'created_at' => (Time.now - 1800).to_s, 'stories' => ['222']}
            }
          }
      end

      def sorted_branches
        @sorted_branches ||= {
            'branches' => {
                'some_branch' => {
                    'created_at' => (Time.now - 1800).to_s,
                    'ref' => 'some_branch',
                    'status' => 'success',
                    'stories' => ['222']
                },
                'some_old_branch' => {
                    'created_at' => (Time.now - 3600).to_s,
                    'ref' => 'some_old_branch',
                    'stories' => ['111']},
            },
            'version' => '1.0.0',
        }
      end
    end

    class MockGit
      def read_file_from_merge_branch; end
      def add_and_commit(_,_,_=nil); end

      def in_dir
        yield
      end
      def in_temp_merge_branch
        yield
      end
    end
  end
end
