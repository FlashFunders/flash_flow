require 'logger'

require 'flash_flow/cmd_runner'
require 'flash_flow/git'
require 'flash_flow/branch'
require 'flash_flow/lock'
require 'flash_flow/notifier'

module FlashFlow
  class Deploy

    class OutOfSyncWithRemote < RuntimeError ; end

    attr_reader :cmd_runner, :branch, :pull_requests, :pr_title, :pr_body, :force

    def initialize(opts={})
      @do_not_merge = opts[:do_not_merge]
      @force = opts[:force]

      @cmd_runner = CmdRunner.new(opts.merge(logger: logger))
      @merge_remote = FlashFlow::Config.configuration.merge_remote
      @merge_branch = FlashFlow::Config.configuration.merge_branch
      @git = Git.new(@cmd_runner, @merge_remote, @merge_branch, Config.configuration.master_branch, Config.configuration.use_rerere)
      @working_branch = @git.current_branch
      @lock = Lock::Base.new(Config.configuration.lock)
      @notifier = Notifier::Base.new(Config.configuration.notifier)
      @branches = Branch::Collection.new(@git.remotes_hash, Config.configuration.branches)
      @stories = [opts[:stories]].flatten.compact
    end

    def logger
      @logger ||= FlashFlow::Config.configuration.logger
    end

    def run
      check_repo
      puts "Building #{@merge_branch}... Log can be found in #{FlashFlow::Config.configuration.log_file}"
      logger.info "\n\n### Beginning #{@merge_branch} merge ###\n\n"

      fetch(@merge_remote)
      @git.in_original_merge_branch do
        @git.initialize_rerere
      end

      begin
        @lock.with_lock do
          open_pull_request

          @git.reset_merge_branch
          @git.in_merge_branch do
            merge_branches
            commit_branch_info
            @git.commit_rerere
          end

          @git.push_merge_branch
        end

        print_errors
        logger.info "### Finished #{@merge_branch} merge ###"
      rescue Lock::Error, OutOfSyncWithRemote => e
        @cmd_runner.run("git checkout #{@working_branch}")
        puts 'Failure!'
        puts e.message
      end
    end

    def check_repo
      if @git.staged_and_working_dir_files.any?
        raise RuntimeError.new('You have changes in your working directory. Please stash and try again')
      end
    end

    def fetch(remote)
      @fetched_remotes ||= {}
      unless @fetched_remotes[remote]
        @git.fetch(remote)
        @fetched_remotes[remote] = true
      end
    end

    def commit_branch_info
      if Config.configuration.branch_info_file
        @stories.each do |story_id|
          @branches.add_story(@merge_remote, @working_branch, story_id)
        end
        Branch::Store.new(Config.configuration.branch_info_file, @git, logger: logger).merge_and_save(@branches.branches)
        @git.add_and_commit(Config.configuration.branch_info_file, 'Branch Info', add: { force: true })
      end
    end

    def merge_branches
      @branches.mergeable.each do |branch|
        remotes = @git.fetch_remotes_for_url(branch.remote_url)
        remote = (Config.configuration.remotes & remotes).first
        if remote.nil?
          raise RuntimeError.new("No remote found for #{pull_request.head.repo.ssh_url}. Please run 'git remote add *your_remote_name* #{pull_request.head.repo.ssh_url}' and try again.")
        end

        git_merge(branch)
      end
    end

    def git_merge(branch)
      @git.run("rev-parse #{branch.remote}/#{branch.ref}")
      branch.sha = @git.last_stdout.strip

      if merge_success?(branch)
        @branches.mark_success(branch)
      else
        @branches.mark_failure(branch, merge_rollback)
        @notifier.merge_conflict(branch) unless branch.ref == @working_branch
      end
    end

    def open_pull_request
      return false if [Config.configuration.master_branch, @merge_branch].include?(@working_branch)

      # TODO - This should use the actual remote for the branch we're on
      @git.push(@working_branch, force: @force)
      raise OutOfSyncWithRemote.new("Your branch is out of sync with the remote. If you want to force push, run 'flash_flow -f'") unless @git.last_success?

      # TODO - This should use the actual remote for the branch we're on
      if @do_not_merge
        @branches.remove_from_merge(@merge_remote, @working_branch)
      else
        @branches.add_to_merge(@merge_remote, @working_branch)
      end
    end

    def print_errors
      puts format_errors
    end

    def format_errors
      errors = []
      branch_not_merged = nil
      @branches.failures.each do |full_ref, failure|
        if failure.ref == @working_branch
          branch_not_merged = "\nERROR: Your branch did not merge to #{@git.merge_branch}. Run the following commands to fix the merge conflict and then re-run this script:\n\n  git checkout #{failure.metadata['conflict_sha']}\n  git merge #{@working_branch}\n  # Resolve the conflicts\n  git add <conflicted files>\n  git commit --no-edit"
        else
          errors << "WARNING: Unable to merge branch #{failure.remote}/#{failure.ref} to #{@git.merge_branch} due to conflicts."
        end
      end
      errors << branch_not_merged if branch_not_merged

      if errors.empty?
        "Success!"
      else
        errors.join("\n")
      end
    end

    def merge_success?(branch)
      fetch(branch.remote)

      @git.run("merge #{branch.remote}/#{branch.ref}")

      @git.last_success? || @git.rerere_resolve!
    end

    private

    def merge_rollback
      @git.run("reset --hard HEAD")
      @git.run("rev-parse HEAD")
      @git.last_stdout.strip
    end
  end
end
