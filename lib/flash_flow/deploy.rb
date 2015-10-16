require 'logger'

require 'flash_flow/git'
require 'flash_flow/data'
require 'flash_flow/lock'
require 'flash_flow/notifier'
require 'flash_flow/branch_merger'

module FlashFlow
  class Deploy

    class OutOfSyncWithRemote < RuntimeError ; end

    def initialize(opts={})
      @do_not_merge = opts[:do_not_merge]
      @force = opts[:force]
      @rerere_forget = opts[:rerere_forget]
      @stories = [opts[:stories]].flatten.compact

      @git = Git.new(Config.configuration.git, logger)
      @lock = Lock::Base.new(Config.configuration.lock)
      @notifier = Notifier::Base.new(Config.configuration.notifier)
      @data = Data::Base.new(Config.configuration.branches, Config.configuration.branch_info_file, @git, logger: logger)
    end

    def logger
      @logger ||= FlashFlow::Config.configuration.logger
    end

    def run
      check_repo
      puts "Building #{@git.merge_branch}... Log can be found in #{FlashFlow::Config.configuration.log_file}"
      logger.info "\n\n### Beginning #{@git.merge_branch} merge ###\n\n"

      fetch(@git.merge_remote)
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
        logger.info "### Finished #{@git.merge_branch} merge ###"
      rescue Lock::Error, OutOfSyncWithRemote => e
        @git.run("checkout #{@git.working_branch}")
        puts 'Failure!'
        puts e.message
      end
    end

    def check_repo
      if @git.staged_and_working_dir_files.any?
        raise RuntimeError.new('You have changes in your working directory. Please stash and try again')
      end
    end

    def commit_branch_info
      @stories.each do |story_id|
        @data.add_story(@git.merge_remote, @git.working_branch, story_id)
      end
      @data.save!
    end

    def merge_branches
      @data.mergeable.each do |branch|
        remote = @git.fetch_remote_for_url(branch.remote_url)
        if remote.nil?
          raise RuntimeError.new("No remote found for #{branch.remote_url}. Please run 'git remote add *your_remote_name* #{branch.remote_url}' and try again.")
        end

        fetch(branch.remote)
        git_merge(branch, branch.ref == @git.working_branch)
      end
    end

    def git_merge(branch, is_working_branch)
      merger = BranchMerger.new(@git, branch)
      forget_rerere = is_working_branch && @rerere_forget

      case merger.do_merge(forget_rerere)
        when :deleted
          @data.mark_deleted(branch)
          @notifier.deleted_branch(branch) unless is_working_branch

        when :success
          branch.sha = merger.sha
          @data.mark_success(branch)
          @data.set_resolutions(branch, merger.resolutions)

        when :conflict
          @data.mark_failure(branch, merger.conflict_sha)
          @notifier.merge_conflict(branch) unless is_working_branch
      end
    end

    def open_pull_request
      return false if [@git.master_branch, @git.merge_branch].include?(@git.working_branch)

      # TODO - This should use the actual remote for the branch we're on
      @git.push(@git.working_branch, force: @force)
      raise OutOfSyncWithRemote.new("Your branch is out of sync with the remote. If you want to force push, run 'flash_flow -f'") unless @git.last_success?

      # TODO - This should use the actual remote for the branch we're on
      if @do_not_merge
        @data.remove_from_merge(@git.merge_remote, @git.working_branch)
      else
        @data.add_to_merge(@git.merge_remote, @git.working_branch)
      end
    end

    def print_errors
      puts format_errors
    end

    def format_errors
      errors = []
      branch_not_merged = nil
      @data.failures.each do |full_ref, failure|
        if failure.ref == @git.working_branch
          branch_not_merged = "\nERROR: Your branch did not merge to #{@git.merge_branch}. Run the following commands to fix the merge conflict and then re-run this script:\n\n  git checkout #{failure.metadata['conflict_sha']}\n  git merge #{@git.working_branch}\n  # Resolve the conflicts\n  git add <conflicted files>\n  git commit --no-edit"
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

    private

    def fetch(remote)
      @fetched_remotes ||= {}
      unless @fetched_remotes[remote]
        @git.fetch(remote)
        @fetched_remotes[remote] = true
      end
    end
  end
end
