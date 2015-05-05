require 'flash_flow/branch_info_store'

module FlashFlow
  class BranchInfo

    attr_reader :filename, :branches

    def initialize(filename, opts={})
      @branches = {}
      @store = BranchInfoStore.new(filename, opts)
    end

    def get_original
      @store.get
    end

    def merge_and_save
      original = get_original

      @branches.each do |full_ref, info|
        info['stories'] ||= []
        original_stories = (original[full_ref] && original[full_ref]['stories']).to_a
        info['stories'] = original_stories | info['stories']
      end

      @store.write(@branches)
    end

    def failures
      @branches.select { |k, v| v['status'] == 'fail' }
    end

    def mark_failure(remote, ref)
      mark_status(remote, ref, 'fail')
    end

    def mark_success(remote, ref)
      mark_status(remote, ref, 'success')
    end

    def add_story(remote, ref, story_id)
      init_info(remote, ref)
      @branches[key(remote, ref)]['stories'] ||= []
      @branches[key(remote, ref)]['stories'] << story_id
    end

    private

    def mark_status(remote, ref, status)
      init_info(remote, ref)
      @branches[key(remote, ref)]['status'] = status
    end

    def key(remote, ref)
      "#{remote}/#{ref}"
    end

    def init_info(remote, ref)
      @branches[key(remote, ref)] ||= { 'branch' => ref, 'remote' => remote }
    end

  end

  class BranchInfoStore
    def initialize(filename, opts={})
      @filename = filename
      @logger = opts[:logger] || Logger.new('/dev/null')
    end

    def get(file=File.open(@filename, 'r'))
      JSON.parse(file.read)
    rescue JSON::ParserError
      @logger.info "Unable to read branch info from file: #{@filename}"
      {}
    end

    def write(branches, file=File.open(@filename, 'w'))
      file.puts branches.to_json
      file.close
    end

  end
end
