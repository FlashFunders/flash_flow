require 'pivotal-tracker'
require 'time'
require 'flash_flow/time_helper'

module FlashFlow
  module IssueTracker
    class Pivotal
      include TimeHelper

      def initialize(branches, git, opts={})
        @branches = branches
        @git = git
        @timezone = opts['timezone'] || "UTC"
        @project_id = opts['project_id']

        PivotalTracker::Client.token = opts['token']
        PivotalTracker::Client.use_ssl = true
        @release_label_prefix = Regexp.new("^#{opts['release_label_prefix'] || 'release'}", Regexp::IGNORECASE)
      end

      def stories_pushed
        if merged_working_branch
          merged_working_branch.stories.to_a.each do |story_id|
            finish(story_id)
          end
        end
      end

      def stories_delivered
        merged_branches.each do |branch|
          branch.stories.to_a.each do |story_id|
            deliver(story_id)
          end
        end

        removed_and_failed_branches.each do |branch|
          branch.stories.to_a.each do |story_id|
            undeliver(story_id)
          end
        end
      end

      def production_deploy
        shipped_branches.each do |branch|
          branch.stories.to_a.each do |story_id|
            comment(story_id)
          end
        end
      end

      def release_notes(hours, file=STDOUT)
        release_stories = done_and_current_stories.map do |story|
          shipped_text = has_shipped_text?(story)
          format_release_data(story.id, story.name, shipped_text) if shipped_text
        end.compact

        release_notes = release_by(release_stories, hours)
        print_release_notes(release_notes, file)
      end

      def story_deployable?(story_id)
        story = get_story(story_id)

        story && story.current_state == 'accepted'
      end

      def story_link(story_id)
        story = get_story(story_id)

        story.url if story
      end

      def story_title(story_id)
        story = get_story(story_id)

        story.name if story
      end

      def release_keys(story_id)
        story = get_story(story_id)

        return [] unless story && story.labels

        story.labels.split(",").map(&:strip).select { |label| label =~ @release_label_prefix }.map(&:strip)
      end

      def stories_for_release(release_key)
        stories_for_label(release_key)
      end

      private

      def project
        @project ||= PivotalTracker::Project.find(@project_id)
      end

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
          unless has_shipped_text?(story)
            story.notes.create(:text => with_time_zone(@timezone) { Time.now.strftime(note_time_format) })
          end
        end
      end

      def note_prefix
        'Shipped to production on'
      end

      def note_time_format
        "#{note_prefix} %m/%d/%Y at %H:%M"
      end

      def format_release_data(story_id, story_name, shipped_text)
        {id: story_id, title: story_name, time: Time.strptime(shipped_text, note_time_format)}
      end

      def shipped?(branch)
        branch.sha && @git.master_branch_contains?(branch.sha)
      end

      def done_and_current_stories
        [project.iteration(:done).last(2).map(&:stories) + project.iteration(:current).stories].flatten
      end

      def stories_for_label(label)
        @stories_for_label ||= {}
        @stories_for_label[label] ||= project.stories.all(label: label).map(&:id)
      end

      def release_by(release_stories, hours)
        release_stories
          .select { |story| story[:time] >= (Time.now - hours.to_i*60*60) }
          .sort_by {|story| story[:time] }.reverse
      end

      def print_release_notes(release_notes, file=nil)
        file ||= STDOUT
        release_notes.each do |story|
          file.puts "PT##{story[:id]} #{story[:title]} (#{story[:time]})"
        end
      end

      def get_story(story_id)
        @stories ||= {}
        @stories[story_id] ||= project.stories.find(story_id)
      end

      def already_has_comment?(story, comment)
        story.notes.all.map(&:text).detect { |text| text =~ comment }
      end

      def has_shipped_text?(story)
        already_has_comment?(story, Regexp.new("^#{note_prefix}"))
      end

      def shipped_branches
        @branches.select { |b| shipped?(b) }
      end

      def merged_branches
        @branches.select { |b| b.success? }
      end

      def removed_and_failed_branches
        @branches.select { |b| b.removed? || b.fail? }
      end

      def merged_working_branch
        merged_branches.detect { |b| b.ref == @git.working_branch }
      end

    end
  end
end
