module FlashFlow
  class BranchMerger

    attr_reader :conflict_sha, :resolutions

    def initialize(git, branch)
      @git = git
      @branch = branch
    end

    def do_merge(rerere_forget)
      return :deleted if sha.nil?

      @git.run("merge --no-ff #{@branch.remote}/#{@branch.ref}")

      if @git.last_success? || try_rerere(rerere_forget)
        return :success
      else
        @conflict_sha = merge_rollback
        return :conflict
      end
    end

    def sha
      @sha if defined?(@sha)
      @sha = get_sha
    end

    private

    def try_rerere(rerere_forget)
      if rerere_forget
        @git.run('rerere forget')
        false
      else
        @resolutions = @git.rerere_resolve!
      end
    end

    def get_sha
      @git.run("rev-parse #{@branch.remote}/#{@branch.ref}")
      @git.last_stdout.strip if @git.last_success?
    end

    def merge_rollback
      @git.run("reset --hard HEAD")
      @git.run("rev-parse HEAD")
      @git.last_stdout.strip
    end
  end
end

