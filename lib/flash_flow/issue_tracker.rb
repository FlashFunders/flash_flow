require 'logger'

require 'flash_flow/git'
require 'flash_flow/data'
require 'flash_flow/data/store'
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

      def release_notes(hours, file=STDOUT)
        issue_tracker.release_notes(hours, file) if issue_tracker.respond_to?(:release_notes)
      end

      def story_deployable?(story_id)
        issue_tracker.story_deployable?(story_id) if issue_tracker.respond_to?(:story_deployable?)
      end

      def story_link(story_id)
        issue_tracker.story_link(story_id) if issue_tracker.respond_to?(:story_link)
      end

      def story_title(story_id)
        issue_tracker.story_title(story_id) if issue_tracker.respond_to?(:story_title)
      end

      def release_keys(story_id)
        issue_tracker.release_keys(story_id) if issue_tracker.respond_to?(:release_keys)
      end

      def stories_for_release(release_key)
        issue_tracker.stories_for_release(release_key) if issue_tracker.respond_to?(:stories_for_release)
      end

      private

      def git
        @git ||= Git.new(Config.configuration.git, Config.configuration.logger)
      end

      def get_branches
        branch_info_store = Data::Base.new(Config.configuration.branches, Config.configuration.branch_info_file, git, logger: Config.configuration.logger)

        branch_info_store.saved_branches
      end

      def issue_tracker
        @issue_tracker ||= @issue_tracker_class && @issue_tracker_class.new(get_branches, git, @config['class'])
      end
    end
  end
end
