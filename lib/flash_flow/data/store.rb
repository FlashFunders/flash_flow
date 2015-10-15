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

      def merge(old, new)
        merged_branches = new.dup

        merged_branches.each do |_, info|
          info.updated_at = Time.now
          info.created_at ||= Time.now
        end

        old.each do |full_ref, info|
          if merged_branches.has_key?(full_ref)
            merged_branches[full_ref].created_at = info.created_at
            merged_branches[full_ref].stories = info.stories.to_a | merged_branches[full_ref].stories.to_a
          else
            merged_branches[full_ref] = info
            merged_branches[full_ref].status = nil
          end
        end

        merged_branches
      end

      def merge_and_save(new_branches)
        write(merge(get, new_branches))
      end

      def fetch
        get.values
      end

      def get
        file_contents = @git.read_file_from_merge_branch(@filename)
        hash = JSON.parse(file_contents)
        hash.each do |key, val|
          hash[key] = Branch.from_hash(val)
        end
        hash

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