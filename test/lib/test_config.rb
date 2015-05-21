require 'minitest_helper'

module FlashFlow
  class TestConfig < Minitest::Test
    def setup
      @config_hash = {
          'git' => {
            'use_rerere' => true,
            'merge_remote' => 'arbitrary_remote',
            'merge_branch' => 'acceptance',
            'master_branch' => 'master',
            'remotes' => ['origin']
          },
          'branch_info_file' => 'some_file.txt',
          'notifier' => {
              'class' => {
                  'name' => 'NotifierClass'
              }
          },
          'issue_tracker' => {
              'class' => {
                  'name' => 'IssueTrackerClass'
              }
          },
          'lock' => {
              'class' => {
                  'name' => 'LockClass'
              }
          },
          'branches' => {
              'class' => {
                  'name' => 'BranchClass'
              }
          }
      }

      reset_config!
    end

    def test_that_it_sets_all_attrs
      File.stub(:read, @config_hash.to_yaml) do
        Config.configure!('unused_file_name.yml')
        assert('some_file.txt' == config.branch_info_file)
        assert({
                   'use_rerere' => true,
                   'merge_remote' => 'arbitrary_remote',
                   'merge_branch' => 'acceptance',
                   'master_branch' => 'master',
                   'remotes' => ['origin']
               } == config.git)
        assert({ 'class' => { 'name' => 'NotifierClass' }} == config.notifier)
        assert({ 'class' => { 'name' => 'IssueTrackerClass' }} == config.issue_tracker)
        assert({ 'class' => { 'name' => 'LockClass' }} == config.lock)
        assert({ 'class' => { 'name' => 'BranchClass' }} == config.branches)
      end
    end

    def test_that_it_blows_up
      @config_hash.delete('git')

      File.stub(:read, @config_hash.to_yaml) do
        assert_raises FlashFlow::Config::IncompleteConfiguration do
          Config.configure!('unused_file_name.yml')
        end
      end
    end

    def test_that_it_sets_defaults
      File.stub(:read, {'git' => {}}.to_yaml) do
        Config.configure!('unused_file_name.yml')
        assert('README.rdoc' == config.branch_info_file)
        assert_nil(config.notifier)
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
