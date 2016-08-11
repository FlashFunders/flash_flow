module FlashFlow
  class MergeOrder

    def initialize(git, branches)
      @git = git
      @branches = branches
    end

    def get_order
      new_branches, old_branches = @branches.partition { |branch| branch.merge_order.nil? }
      branches = old_branches.sort_by(&:merge_order) + new_branches

      unchanged, changed = branches.partition { |branch| current_sha(branch) == branch.sha }
      my_branch_index = changed.find_index { |branch| branch.ref == @git.working_branch }
      my_branch_changed = my_branch_index ? changed.delete_at(my_branch_index) : nil

      [unchanged, changed, my_branch_changed].flatten.compact
    end

    private

    def current_sha(branch)
      @git.get_sha("#{@git.remote}/#{branch.ref}")
    end

  end
end
