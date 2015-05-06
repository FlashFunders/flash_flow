require 'json'

module FlashFlow
  class BranchInfoStore
    def initialize(filename, git, opts={})
      @filename = filename
      @git = git
      @logger = opts[:logger] || Logger.new('/dev/null')
    end

    def merge(old, new)
      merged_branches = new.dup

      old.each do |full_ref, info|
        if merged_branches.has_key?(full_ref)
          merged_branches[full_ref]['created_at'] = info['created_at']
          merged_branches[full_ref]['stories'] = info['stories'].to_a | merged_branches[full_ref]['stories'].to_a
        else
          merged_branches[full_ref] = info.dup
          merged_branches[full_ref]['status'] = 'Unknown'
        end
      end

      merged_branches.each do |_, info|
        info['created_at'] ||= Time.now
      end

      merged_branches
    end

    def merge_and_save(new_branches)
      write(merge(get, new_branches))
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
      end
    end
  end
end
