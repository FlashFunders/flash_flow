require 'minitest_helper'
require 'minitest/stub_any_instance'

module FlashFlow
  class TestBranchMerger < Minitest::Test

    def setup
    end

    def test_deleted_branch
      merger.stub(:sha, nil) do
        merger.do_merge(true)
        assert_equal(merger.result, :deleted)
      end
    end

    def test_successful_merge
      git.expect(:last_success?, true)

      merger.stub(:sha, 'some_sha') do
        assert_equal(merger.do_merge(false), :success)
      end
    end

    def test_successful_rerere
      git.expect(:last_success?, false)
          .expect(:rerere_resolve!, true)

      merger.stub(:sha, 'some_sha') do
        assert_equal(merger.do_merge(false), :success)
      end
    end

    def test_rerere_forget
      git.expect(:last_success?, false)
          .expect(:run, true, [ 'rerere forget' ])
          .expect(:run, true, [ 'reset --hard HEAD' ])
          .expect(:run, true, [ 'rev-parse HEAD' ])
          .expect(:last_stdout, 'conflict sha', )

      merger.stub(:sha, 'some_sha') do
        assert_equal(merger.do_merge(true), :conflict)
      end
    end

    def test_failed_rerere
      git.expect(:last_success?, false)
          .expect(:rerere_resolve!, false)
          .expect(:run, true, [ 'reset --hard HEAD' ])
          .expect(:run, true, [ 'rev-parse HEAD' ])
          .expect(:last_stdout, 'conflict sha', )

      merger.stub(:sha, 'some_sha') do
        assert_equal(merger.do_merge(false), :conflict)
        assert_equal(merger.conflict_sha, 'conflict sha')
      end
    end

    private

    def merger
      @merger ||= BranchMerger.new(git, branch)
    end

    def branch
      @branch ||= Data::Branch.from_hash({'ref' => 'pushing_branch', 'remote' => 'origin', 'status' => 'fail', 'stories' => []})
    end

    def git
      return @git if @git

      @git = Minitest::Mock.new
      @git.expect(:run, true, ["merge --no-ff #{branch.remote}/#{branch.ref}"])
    end

  end
end
