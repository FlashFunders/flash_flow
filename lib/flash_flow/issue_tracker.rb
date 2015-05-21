require 'logger'

require 'flash_flow/git'
require 'flash_flow/branch'
require 'flash_flow/branch/store'
require 'flash_flow/issue_tracker/pivotal'

module FlashFlow
  module IssueTracker
    class Base
      def initialize(_config=nil)
        @config = _config
        issue_tracker_class_name = @config && @config['class'] && @config['class']['name']
        return unless issue_tracker_class_name

        @issue_tracker_class = Object.const_get(issue_tracker_class_name)
      end

      def stories_pushed
        issue_tracker.stories_pushed if issue_tracker.respond_to?(:stories_pushed)
      end

      def stories_delivered
        issue_tracker.stories_delivered if issue_tracker.respond_to?(:stories_delivered)
      end

      def production_deploy
        issue_tracker.production_deploy if issue_tracker.respond_to?(:production_deploy)
      end

      private

      def git
        @git ||= Git.new(Config.configuration.git, Config.configuration.logger)
      end

      def get_branches
        branch_info_store = Branch::Store.new(Config.configuration.branch_info_file, git, logger: Config.configuration.logger)

        branch_info_store.get
      end

      def issue_tracker
        @issue_tracker ||= @issue_tracker_class && @issue_tracker_class.new(get_branches, git, @config)
      end
    end
  end
end
