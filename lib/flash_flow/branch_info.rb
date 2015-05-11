module FlashFlow
  class BranchInfo

    attr_reader :branches

    def initialize
      @branches = {}
    end

    def failures
      @branches.select { |k, v| v['status'] == 'fail' }
    end

    def mark_failure(remote, ref, conflict_sha)
      mark_status(remote, ref, 'fail', conflict_sha)
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

    def mark_status(remote, ref, status, conflict_sha)
      init_info(remote, ref)
      @branches[key(remote, ref)]['status'] = status
      @branches[key(remote, ref)]['conflict_sha'] = conflict_sha
    end

    def key(remote, ref)
      "#{remote}/#{ref}"
    end

    def init_info(remote, ref)
      @branches[key(remote, ref)] ||= { 'branch' => ref, 'remote' => remote }
    end

  end

end
