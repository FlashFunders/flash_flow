module FlashFlow
  class MergeOrder

    def initialize(git, branches)
      @git = git
      @branches = branches
    end

    def get_order
      branches = @branches.sort_by(&:merge_order)

      unchanged, changed = branches.partition { |branch| current_sha(branch) == branch.sha }
      my_branch_index = changed.find_index { |branch| branch.ref == @git.working_branch }
      my_branch_changed = my_branch_index ? changed.delete_at(my_branch_index) : nil

      [unchanged, changed, my_branch_changed].flatten.compact
    end

    private

    def current_sha(branch)
      @git.run("rev-parse #{branch.remote}/#{branch.ref}")
      @git.last_stdout.strip if @git.last_success?
    end

  end
end
