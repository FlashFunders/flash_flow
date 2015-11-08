require 'json'
require 'flash_flow/data'

module FlashFlow
  module Data
    class Store
      def initialize(filename, git, opts={})
        @filename = filename
        @git = git
        @logger = opts[:logger] || Logger.new('/dev/null')
      end

      def get
        file_contents = @git.read_file_from_merge_branch(@filename)
        JSON.parse(file_contents)

      rescue JSON::ParserError, Errno::ENOENT
        @logger.error "Unable to read branch info from file: #{@filename}"
        {}
      end

      def write(branches, file=nil)
        @git.in_temp_merge_branch do
          file ||= File.open(@filename, 'w')
          file.puts JSON.pretty_generate(sort_branches(branches))
          file.close

          @git.add_and_commit(@filename, 'Branch Info', add: { force: true })
        end
      end

      private

      def sort_branches(branches)
        return branches unless branches.is_a?(Hash)
        sorted_branches = {}
        branches.keys.sort.each { |key| sorted_branches[key] = sort_branches(branches[key]) }
        sorted_branches
      end
    end
  end
end
