require 'pivotal-tracker'

module FlashFlow
  module IssueTracker
    class Pivotal

      def initialize(branches, opts={})
        @branches = branches

        PivotalTracker::Client.token = opts['token']
        PivotalTracker::Client.use_ssl = true
        @project = PivotalTracker::Project.find(opts['project_id'])
      end

      def stories_pushed
        merged_branches.each do |_, branch|
          branch.stories.to_a.each do |story_id|
            finish(story_id)
          end
        end
      end

      private

      def finish(story_id)
        story = @project.stories.find(story_id)
        if story && story.current_state == 'started'
          story.current_state = 'finished'
          story.update
        end
      end

      def merged_branches
        @branches.select { |_, v| v.success? }
      end
    end
  end
end
