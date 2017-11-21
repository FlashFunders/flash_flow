module FlashFlow
  class BranchMerger

    attr_reader :conflict_sha, :resolutions, :result, :result_sha

    def initialize(git, result_sha, merge_sha)
      @git = git
      @result_sha = result_sha
      @branch = merge_sha
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


    def do_merge_new(rerere_forget)
      if sha.nil?
        @result = :deleted
        return
      end
      #
      # their_commit = @git.repo.branches["#{@git.remote}/#{@branch.ref}"].target_id
      # our_commit = @git.repo.head.target_id
      repo = @git.repo
      index = repo.merge_commits(@result_sha, @branch)

      require 'byebug'; debugger

      if !index.conflicts? || try_rerere_x(index, rerere_forget)
        tree = index.write_tree(@git.repo)
        base_commit_options = {author:    { name: "Matt", email: "matt@test.com" },committer: { name: "Matt", email: "matt@test.com" },update_ref: 'HEAD'}
        commit_options = base_commit_options.merge(parents: [@result_sha.oid], tree: tree, message: 'branch commit')
        @result_sha = Rugged::Commit.create(repo, commit_options)
        @result = :success
      else
        @conflict_sha = merge_rollback
        @result = :conflict
      end
    end

    def sha
      return @result_sha
    #   @sha if defined?(@sha)
    #   @sha = get_sha
    end

    private

    def try_rerere(rerere_forget)
      commit_tree = index.write_tree(@repo)
      if rerere_forget
        @git.run('rerere forget')
        false
      else
        @resolutions = @git.rerere_resolve!
      end
    end

    def try_rerere_x(index, rerere_forget)

      if rerere_forget
        @git.run('rerere forget')
        false
      else
        index.conflicts.each do |conflict|

          Dir.glob(@git.repo.path + '/rr-cache/**/*preimage*') do |f|
            puts f if index.merge_file(f)[:data].gsub(" #{f}", '') == File.read(f)
          end
        end
        # @resolutions = @git.rerere_resolve!
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

