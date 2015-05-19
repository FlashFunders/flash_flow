require 'pivotal-tracker'

module FlashFlow
  module IssueTracker
    class Pivotal

      def initialize(branches, git, opts={})
        @branches = branches
        @git = git

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

      def stories_delivered
        merged_branches.each do |_, branch|
          branch.stories.to_a.each do |story_id|
            deliver(story_id)
          end
        end
        removed_branches.each do |_, branch|
          branch.stories.to_a.each do |story_id|
            undeliver(story_id)
          end
        end
      end

      def production_deploy
        shipped_branches.each do |_, branch|
          branch.stories.to_a.each do |story_id|
            comment(story_id)
          end
        end
      end

      private

      def undeliver(story_id)
        story = get_story(story_id)

        if story && story.current_state == 'delivered'
          story.current_state = 'finished'
          story.update
        end
      end

      def deliver(story_id)
        story = get_story(story_id)

        if story && story.current_state == 'finished'
          story.current_state = 'delivered'
          story.update
        end
      end

      def finish(story_id)
        story = get_story(story_id)

        if story && story.current_state == 'started'
          story.current_state = 'finished'
          story.update
        end
      end

      def comment(story_id)
        story = get_story(story_id)
        if story
          note_prefix = 'Shipped to production on'
          unless already_has_comment?(story, Regexp.new("^#{note_prefix}"))
            story.notes.create(:text => Time.now.strftime("#{note_prefix} %m/%d/%Y at %H:%M"))
          end
        end
      end

      def shipped?(branch)
        @git.master_branch_contains?(branch.sha)
      end

      def get_story(story_id)
        @project.stories.find(story_id)
      end

      def already_has_comment?(story, comment)
        story.notes.all.map(&:text).detect { |text| text =~ comment }
      end

      def shipped_branches
        @branches.select { |_, b| shipped?(b) }
      end

      def merged_branches
        @branches.select { |_, v| v.success? }
      end

      def removed_branches
        @branches.select { |_, v| v.removed? }
      end
    end
  end
end
