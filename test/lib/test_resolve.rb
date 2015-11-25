require 'minitest_helper'

module FlashFlow
  class TestResolve< Minitest::Test

    class ResolveTester < Resolve
      def in_working_branch
        yield
      end

      def working_branch
        'working_branch'
      end

      def merge_conflicted
        true
      end

      def launch_bash
        puts 'launch_bash'
      end

      def rerere
        puts 'rerere'
      end

      def git_reset
        puts 'git_reset'
      end

      def branch
        Data::Branch.from_hash({ 'metadata' => { 'conflict_sha' => '123' }})
      end
    end

    def setup
      @resolve_tester = ResolveTester.new({ 'merge_branch' => 'test_acceptance',
                               'merge_remote' => 'test_remote',
                               'master_branch' => 'test_master',
                               'remotes' => ['fake_origin'],
                               'use_rerere' => true
                             }, 'some_file')

      @resolve = Resolve.new({ 'merge_branch' => 'test_acceptance',
                                            'merge_remote' => 'test_remote',
                                            'master_branch' => 'test_master',
                                            'remotes' => ['fake_origin'],
                                            'use_rerere' => true
                                          }, 'some_file')
    end

    def test_no_conflict_sha
      @resolve_tester.stub(:branch, Data::Branch.from_hash({ 'metadata' => { }})) do
        assert_raises(Resolve::NothingToResolve) { @resolve_tester.start }
      end
    end

    def test_conflicts_already_resolved
      @resolve_tester.stub(:unresolved_conflicts, []) do
        assert_output(/You have already resolved all conflicts/) { @resolve_tester.start }
      end
    end

    def test_user_did_not_resolve_conflicts
      @resolve_tester.stub(:unresolved_conflicts, ['conflict']) do
        assert_output(/launch_bash.*rerere.*There are still.*git_reset/m) { @resolve_tester.start }
      end
    end

  end
end
