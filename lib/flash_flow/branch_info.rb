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

    def merge_and_save
      raise 'Original branch info not loaded.' if original.nil?

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

end
