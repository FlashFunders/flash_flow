require 'flash_flow/merge_master/release_graph'

module FlashFlow
  module MergeMaster
    class Status
      attr_reader :issue_tracker, :collection, :stories, :releases

      def initialize(issue_tracker_config, branches_config, branch_info_file, git_config, opts={})
        @issue_tracker = IssueTracker::Base.new(issue_tracker_config)
        @collection = Data::Base.new(branches_config, branch_info_file, Git.new(git_config)).merged_branches
      end

      def status(filename=nil)
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
          sub_g.output(png: "./graph-#{i}.png")

          branch_hash[branch] =
              Hash.new.tap do |hash|
                hash[:name] = branch.ref
                hash[:branch_url] = collection.branch_link(branch)
                hash[:branch_can_ship?] = collection.can_ship?(branch)
                hash[:connected_branches] = connected_branches
                hash[:image] = "#{`pwd`}/graph-#{i}.png"
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
          b[:shippable?] = b[:branch_can_ship?] &&
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
        arr.select { |story| !@stories[story][:can_ship?] }
      end

      def story_info_hash(story_id)
        {
            id: story_id,
            url: issue_tracker.story_link(story_id),
            title: issue_tracker.story_title(story_id),
            can_ship?: issue_tracker.story_deployable?(story_id),
            release_keys: issue_tracker.release_keys(story_id)
        }
      end

    end
  end
end
