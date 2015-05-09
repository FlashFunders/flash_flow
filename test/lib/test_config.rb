require 'minitest_helper'

module FlashFlow
  class TestConfig < Minitest::Test
    def setup
      @config_hash = {
          'use_rerere' => true,
          'merge_branch' => 'acceptance',
          'master_branch' => 'master',
          'repo' => 'flashfunders/flash_flow',
          'unmergeable_label' => 'some_label',
          'do_not_merge_label' => 'dont merge',
          'branch_info_file' => 'some_file.txt',
          'hipchat_token' => ENV['HIPCHAT_TOKEN'],
          'issue_tracker' => {
              'class' => 'IssueTrackerClass'
          },
          'lock' => {
              'class' => 'LockClass'
          }
      }

      reset_config!
    end

    def test_that_it_sets_all_attrs
      File.stub(:read, @config_hash.to_yaml) do
        Config.configure!('unused_file_name.yml')
        assert(true == config.use_rerere)
        assert('acceptance' == config.merge_branch)
        assert('master' == config.master_branch)
        assert('flashfunders/flash_flow' == config.repo)
        assert('some_label' == config.unmergeable_label)
        assert('dont merge' == config.do_not_merge_label)
        assert('some_file.txt' == config.branch_info_file)
        assert('hip_token' == config.hipchat_token)
        assert({ 'class' => 'IssueTrackerClass' } == config.issue_tracker)
        assert({ 'class' => 'LockClass' } == config.lock)
      end
    end

    def test_that_it_blows_up
      @config_hash.delete('repo')

      File.stub(:read, @config_hash.to_yaml) do
        assert_raises FlashFlow::Config::IncompleteConfiguration do
          Config.configure!('unused_file_name.yml')
        end
      end
    end

    def test_that_it_sets_defaults
      File.stub(:read, { 'repo' => 'some_repo' }.to_yaml) do
        Config.configure!('unused_file_name.yml')
        assert(true == config.use_rerere)
        assert('origin' == config.merge_remote)
        assert('acceptance' == config.merge_branch)
        assert('master' == config.master_branch)
        assert('unmergeable' == config.unmergeable_label)
        assert('do not merge' == config.do_not_merge_label)
        assert('README.rdoc' == config.branch_info_file)
        assert(['origin'] == config.remotes)
        assert('hip_token' == config.hipchat_token)
        assert_nil(config.issue_tracker)
        assert_nil(config.lock)
      end
    end
    
    private
    
    def config
      Config.configuration
    end
  end
end
