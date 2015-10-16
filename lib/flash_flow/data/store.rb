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
        @git.in_merge_branch do
          file ||= File.open(@filename, 'w')
          file.puts JSON.pretty_generate(branches)
          file.close

          @git.add_and_commit(@filename, 'Branch Info', add: { force: true })
        end
      end
    end
  end
end