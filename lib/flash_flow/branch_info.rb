require 'flash_flow/branch_info_store'

module FlashFlow
  class BranchInfo

    attr_reader :filename, :branches, :original

    def initialize(filename, opts={})
      @branches = {}
      @store = BranchInfoStore.new(filename, opts)
    end

    def load_original
      @original = @store.get
    end

    def merge_original
      raise 'Original branch info not loaded.' if original.nil?

      merged_branches = @branches.dup

      # iterate over original and add all existing branches
      original.each do |full_ref, info|
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

    def merge_and_save
      @store.write(merge_original)
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

end
