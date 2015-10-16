require 'minitest_helper'
require 'flash_flow/data/store'

module FlashFlow
  module Data
    class TestBranch < Minitest::Test

      def test_merge_returns_self_if_other_is_nil
        branch = Branch.from_hash(branch_hash)
        assert_equal(branch.merge(nil), branch)
      end

      def test_merge_keeps_the_oldest_created_at
        new_branch = Branch.from_hash(branch_hash)
        old_branch = Branch.from_hash(branch_hash)
        old_branch.created_at -= 1000

        assert_equal(new_branch.merge(old_branch).created_at, old_branch.created_at)
        assert_equal(old_branch.merge(new_branch).created_at, old_branch.created_at)
      end

      def test_merge_handles_nil_stories
        new_branch = Branch.from_hash(branch_hash)
        old_branch = Branch.from_hash(branch_hash)

        new_branch.stories = nil
        old_branch.stories = ['456', '789']

        assert_equal(old_branch.merge(new_branch).stories, ['456', '789'])
        assert_equal(new_branch.merge(old_branch).stories, ['456', '789'])
      end

      def test_merge_unions_the_stories
        new_branch = Branch.from_hash(branch_hash)
        old_branch = Branch.from_hash(branch_hash)

        new_branch.stories = ['123', '456']
        old_branch.stories = ['456', '789']

        assert_equal(new_branch.merge(old_branch).stories, ['123', '456', '789'])
      end

      def test_merge_uses_other_status
        new_branch = Branch.from_hash(branch_hash)
        old_branch = Branch.from_hash(branch_hash)

        old_branch.success!
        new_branch.fail!
        old_branch.merge(new_branch)

        assert(old_branch.fail?)
        assert(new_branch.fail?)
      end

      def test_merge_sets_updated_at
        new_branch = Branch.from_hash(branch_hash)
        old_branch = Branch.from_hash(branch_hash)

        original_updated_at = new_branch.updated_at

        assert(old_branch.merge(new_branch).updated_at > original_updated_at)
      end

      def test_merge_sets_created_at_if_not_set
        new_branch = Branch.from_hash(branch_hash)
        old_branch = Branch.from_hash(branch_hash)

        new_branch.created_at = old_branch.created_at = nil

        assert_in_delta(old_branch.merge(new_branch).created_at.to_i, Time.now.to_i, 100)
      end

      def test_from_hash
        branch = Branch.from_hash(branch_hash)
        assert_equal(branch.ref, branch_hash['ref'])
        assert_equal(branch.remote_url, branch_hash['remote_url'])
        assert_equal(branch.remote, branch_hash['remote'])
        assert_equal(branch.status, branch_hash['status'])
        assert_equal(branch.stories, branch_hash['stories'])
        assert_equal(branch.metadata, branch_hash['metadata'])
      end

      def test_from_hash_with_time_objects
        branch_hash['updated_at'] = Time.now - 200
        branch_hash['created_at'] = Time.now - 200
        branch = Branch.from_hash(branch_hash)
        assert_equal(branch.updated_at, branch_hash['updated_at'])
        assert_equal(branch.created_at, branch_hash['created_at'])
      end

      def test_from_hash_with_nil_times
        time = Time.parse('2015-05-22 09:47:07 -0700')
        branch_hash['updated_at'] = branch_hash['created_at'] = nil
        Time.stub(:now, time) do
          branch = Branch.from_hash(branch_hash)

          assert_equal(branch.updated_at, time)
          assert_equal(branch.created_at, time)
        end
      end

      def test_from_hash_with_string_times
        time = Time.parse('2015-05-22 09:47:07 -0700')
        branch_hash['updated_at'] = '2015-05-22 09:47:07 -0700'
        branch_hash['created_at'] = '2015-05-22 09:47:07 -0700'
        branch = Branch.from_hash(branch_hash)
        assert_equal(branch.updated_at, time)
        assert_equal(branch.created_at, time)
      end

      def test_double_equals
        branch1 = Branch.from_hash(branch_hash)
        branch2 = Branch.from_hash(branch_hash)
        assert(branch1 == branch2)

        branch1.remote_url = 'different_url'
        refute(branch1 == branch2)

        branch1.remote_url = branch2.remote_url
        branch1.remote = 'different remote'
        refute(branch1 == branch2)

        branch1.remote = branch2.remote
        branch1.ref = 'different ref'
        refute(branch1 == branch2)
      end

      def test_to_hash
        branch1 = Branch.from_hash(branch_hash)
        assert_equal(branch1.to_hash, branch_hash)
      end

      def test_success
        branch = Branch.new(1,2,3)

        branch.success!
        assert(branch.success?)

        branch.fail!
        refute(branch.success?)
      end

      def test_fail
        branch = Branch.new(1,2,3)

        branch.fail!
        assert(branch.fail?)

        branch.success!
        refute(branch.fail?)
      end

      def test_removed
        branch = Branch.new(1,2,3)

        branch.removed!
        assert(branch.removed?)

        branch.success!
        refute(branch.removed?)
      end

      def test_deleted
        branch = Branch.new(1,2,3)

        branch.deleted!
        assert(branch.deleted?)

        branch.success!
        refute(branch.deleted?)
      end

      def test_unknown
        branch = Branch.new(1,2,3)

        branch.unknown!
        assert(branch.unknown?)

        branch.success!
        refute(branch.unknown?)
      end

      private

      def branch_hash
        @branch_hash ||= {
            'ref' => 'branch 1',
            'remote_url' => 'the_origin_url',
            'remote' => 'origin',
            'sha' => 'random_sha',
            'status' => 'success',
            'resolutions' => {},
            'stories' => ['123'],
            'metadata' => {
                'some' => 'data'
            },
            'updated_at' => Time.now - 1000,
            'created_at' => Time.now - 1000,
        }
      end
    end
  end
end
