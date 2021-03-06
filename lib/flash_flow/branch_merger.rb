module FlashFlow
  class BranchMerger

    attr_reader :conflict_sha, :resolutions, :result

    def initialize(git, branch)
      @git = git
      @branch = branch
    end

    def do_merge(rerere_forget)
      if sha.nil?
        @result = :deleted
        return
      end

      @git.run("merge --no-ff #{@git.remote}/#{@branch.ref}")

      if @git.last_success? || try_rerere(rerere_forget)
        @result = :success
      else
        @conflict_sha = merge_rollback
        @result = :conflict
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
      @git.run("rev-parse #{@git.remote}/#{@branch.ref}")
      @git.last_stdout.strip if @git.last_success?
    end

    def merge_rollback
      @git.run("reset --hard HEAD")
      @git.run("rev-parse HEAD")
      @git.last_stdout.strip
    end
  end
end

