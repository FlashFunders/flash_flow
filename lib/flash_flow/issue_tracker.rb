require 'logger'

require 'flash_flow/cmd_runner'
require 'flash_flow/git'
require 'flash_flow/branch'
require 'flash_flow/branch/store'
require 'flash_flow/issue_tracker/pivotal'

module FlashFlow
  module IssueTracker
    class Base
      def initialize
        issue_tracker_class_name = Config.configuration.issue_tracker && Config.configuration.issue_tracker['class']
        return unless issue_tracker_class_name

        @issue_tracker_class = Object.const_get(issue_tracker_class_name)
        @issue_tracker = @issue_tracker_class.new(get_branches, Config.configuration.issue_tracker)
      end

      def stories_pushed
        @issue_tracker.stories_pushed unless @issue_tracker.nil?
      end

      private

      def get_branches
        git = Git.new(CmdRunner.new(logger: Config.configuration.logger),
                      Config.configuration.merge_remote,
                      Config.configuration.merge_branch,
                      Config.configuration.master_branch,
                      Config.configuration.use_rerere)
        branch_info_store = Branch::Store.new(Config.configuration.branch_info_file, git, logger: Config.configuration.logger)

        branch_info_store.get
      end

    end
  end
end