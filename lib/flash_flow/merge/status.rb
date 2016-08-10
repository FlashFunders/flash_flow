require 'flash_flow/merge/release_graph'

module FlashFlow
  module Merge
    class Status
      attr_reader :issue_tracker, :collection, :stories, :releases

      def initialize(issue_tracker_config, branches_config, branch_info_file, git_config, opts={})
        @issue_tracker = IssueTracker::Base.new(issue_tracker_config)
        @collection = Data::Base.new(branches_config, branch_info_file, ShadowGit.new(git_config)).collection
      end

      def status
        filename = File.dirname(__FILE__) + '/merge_status.csv'
        checkmark = "\u2713".encode('utf-8')

        CSV.open(filename, 'w') do |f|
          f << ['Ready', 'Branch', 'Stories', 'Review', 'Can ship?']
          branches.each do |_, branch_hash|
            f << [
              branch_hash[:shippable?] ? checkmark : 'x',
              branch_hash[:name],
              unshippable_stories(branch_hash[:stories]).empty? ? checkmark : 'x',
              branch_hash[:code_reviewed?] ? checkmark : 'x',
              branch_hash[:can_ship?] ? checkmark : 'x'
            ]
          end
        end

        CSV.foreach(filename) { |row| puts '%-10s %-70s %-10s %-10s %-10s' % row }
      end

      def status_html(filename=nil)
        filename = File.dirname(__FILE__) + '/merge_status.html'
        @branches = branches

        template = ERB.new File.read(File.dirname(__FILE__) + '/merge_status.html.erb')
        html = template.result(binding)
        File.open(filename, 'w') do |f|
          f.puts html
        end
        `open #{filename}`
      end

      def branches
        g = ReleaseGraph.build(collection.current_branches, issue_tracker)

        branch_hash = {}
        collection.current_branches.each_with_index do |branch, i|
          connected_branches = g.connected_branches(branch.ref)
          connected_stories = g.connected_stories(branch.ref)
          connected_releases = g.connected_releases(branch.ref)
          add_stories(connected_stories)
          add_releases(connected_releases)
          sub_g = ReleaseGraph.build(connected_branches, issue_tracker)
          graph_file = sub_g.output("/tmp/graph-#{i}.png")

          branch_hash[branch] =
              Hash.new.tap do |hash|
                hash[:name] = branch.ref
                hash[:branch_url] = collection.branch_link(branch)
                hash[:code_reviewed?] = collection.code_reviewed?(branch)
                hash[:can_ship?] = collection.can_ship?(branch)
                hash[:connected_branches] = connected_branches
                hash[:image] = graph_file
                hash[:my_stories] = branch.stories.to_a
                hash[:stories] = connected_stories
                hash[:releases] = connected_releases
              end
        end

        mark_as_shippable(branch_hash)
        branch_hash
      end

      private

      def add_stories(story_list)
        @stories ||= {}
        story_list.each do |story_id|
          @stories[story_id] ||= story_info_hash(story_id)
        end
      end

      def add_releases(release_list)
        @releases ||= {}
        release_list.each do |release_key|
          @releases[release_key] ||= {stories: issue_tracker.stories_for_release(release_key).map(&:to_s)}
        end
      end

      def mark_as_shippable(branches)
        branches.each do |_, b|
          b[:shippable?] = b[:code_reviewed?] && b[:can_ship?] &&
              unshippable_stories(b[:stories]).empty? &&
              unshippable_releases(b[:releases]).empty?
        end

        branches.each do |_, b|
          b[:shippable?] &= b[:connected_branches].all? do |other_branch|
            branches[other_branch][:shippable?]
          end
        end
      end

      def unshippable_releases(arr)
        arr.select do |release_key|
          !unshippable_stories(@releases[release_key][:stories]).empty?
        end
      end

      def unshippable_stories(arr)
        arr.select { |story| !@stories[story][:accepted?] }
      end

      def stories_accepted_branches
        branches.select { |_, b| unshippable_stories(b[:stories]).empty? }
      end

      def story_info_hash(story_id)
        {
            id: story_id,
            url: issue_tracker.story_link(story_id),
            title: issue_tracker.story_title(story_id),
            accepted?: issue_tracker.story_deployable?(story_id),
            release_keys: issue_tracker.release_keys(story_id)
        }
      end

    end
  end
end
