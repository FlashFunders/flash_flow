require 'graphviz'

module FlashFlow
  module MergeMaster
    class ReleaseGraph
      attr_accessor :branches, :issue_tracker

      def self.build(branches, issue_tracker)
        instance = new(branches, issue_tracker)
        instance.build
        instance
      end

      def initialize(branches, issue_tracker)
        @issue_tracker = issue_tracker
        @branches = branches
      end

      def output(opts={})
        graph.output(opts)
      end

      def build
        queue = []

        branches.each do |branch|
          seen_branches[branch] = true
          queue.unshift([branch, graph.add_node(branch.ref)]) #, color: branch[:shippable?] ? 'green' : 'red', shape: 'record', label: "<f0>#{branch[:name]}")
        end

        while !queue.empty?
          element, node = queue.pop

          case
            when seen_branches.has_key?(element)
              element.stories.to_a.map(&:to_s).each do |story_id|
                story_id = story_id.to_s
                seen_stories[story_id] = true
                find_or_add_node(node, queue, story_id)
              end

            when seen_stories.has_key?(element)
              issue_tracker.release_keys(element).each do |release_key|
                seen_releases[release_key] = true
                find_or_add_node(node, queue, release_key)
              end

            when seen_releases.has_key?(element)
              issue_tracker.stories_for_release(element).map(&:to_s).each do |story_id|
                story_id = story_id.to_s
                seen_stories[story_id] = true
                find_or_add_node(node, queue, story_id)
              end
          end
        end
      end

      def connected_branches(node_id)
        visited = connected(node_id)

        seen_branches.keys.select { |k| visited[k.ref] }
      end

      def connected_stories(node_id)
        visited = connected(node_id)

        seen_stories.keys.select { |k| visited[k] }
      end

      def connected_releases(node_id)
        visited = connected(node_id)

        seen_releases.keys.select { |k| visited[k] }
      end

      private

      def find_or_add_node(node, queue, identifier)
        other_node = graph.find_node(identifier)
        unless other_node
          other_node = graph.add_node(identifier)
          queue.unshift([identifier, other_node])
        end

        graph.add_edge(node, other_node) unless all_neighbors(node).include?(other_node)
      end

      def seen_branches
        @seen_branches ||= {}
      end

      def seen_releases
        @seen_releases ||= {}
      end

      def seen_stories
        @seen_stories ||= {}
      end


      def connected(node_id)
        node = graph.find_node(node_id)
        visited = {}
        search(node, visited) if node

        visited
      end

      def all_neighbors(node)
        (node.neighbors | node.incidents)
      end

      def search(node, visited)
        return if visited[node.id]

        visited[node.id] = true

        all_neighbors(node).each do |neighbor|
          search(neighbor, visited)
        end
      end

      def graph
        @graph ||= GraphViz.new(:G, :type => :graph)
      end
    end
  end
end
