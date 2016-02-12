module FlashFlow
  class MergeOrder

    def initialize(git, branches)
      @git = git
      @branches = branches
    end

    def get_order
      one, two, three = [], [], []

      @branches.each do |branch|
        if branch.ref == @git.working_branch
          three << branch
        elsif current_sha(branch) == branch.sha
          one << branch
        else
          two << branch
        end
      end

      [one, two, three].flatten
    end

    private

    def current_sha(branch)
      @git.run("rev-parse #{branch.remote}/#{branch.ref}")
      @git.last_stdout.strip if @git.last_success?
    end

  end
end
