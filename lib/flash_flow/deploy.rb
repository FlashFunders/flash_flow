require 'logger'

require 'flash_flow/git'
require 'flash_flow/data'
require 'flash_flow/lock'
require 'flash_flow/notifier'
require 'flash_flow/branch_merger'
require 'flash_flow/shadow_repo'

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
      check_version
      check_repo
      puts "Building #{@git.merge_branch}... Log can be found in #{FlashFlow::Config.configuration.log_file}"
      logger.info "\n\n### Beginning #{@git.merge_branch} merge ###\n\n"


      begin
        open_pull_request

        in_shadow_repo do
          @lock.with_lock do
            fetch(@git.merge_remote)
            @git.in_original_merge_branch do
              @git.initialize_rerere
            end

            @git.reset_temp_merge_branch
            @git.in_temp_merge_branch do
              merge_branches
              commit_branch_info
              commit_rerere
            end

            @git.copy_temp_to_merge_branch
            @git.delete_temp_merge_branch
            @git.push_merge_branch
          end
        end

        print_errors
        logger.info "### Finished #{@git.merge_branch} merge ###"
      rescue Lock::Error, OutOfSyncWithRemote => e
        puts 'Failure!'
        puts e.message
      ensure
        @git.run("checkout #{@git.working_branch}")
      end
    end

    def check_repo
      if @git.staged_and_working_dir_files.any?
        raise RuntimeError.new('You have changes in your working directory. Please stash and try again')
      end
    end

    def check_version
      data_version = @data.version
      return if data_version.nil?

      written_version = data_version.split(".").map(&:to_i)
      running_version = FlashFlow::VERSION.split(".").map(&:to_i)

      unless written_version[0] < running_version[0] ||
          (written_version[0] == running_version[0] && written_version[1] <= running_version[1]) # Ignore the point release number
        raise RuntimeError.new("Your version of flash flow (#{FlashFlow::VERSION}) is behind the version that was last used (#{data_version}) by a member of your team. Please upgrade to at least #{written_version[0]}.#{written_version[1]}.0 and try again.")
      end
    end

    def commit_branch_info
      @stories.each do |story_id|
        @data.add_story(@git.merge_remote, @git.working_branch, story_id)
      end
      @data.save!
    end

    def commit_rerere
      current_branches = @data.merged_branches.to_a.select { |branch| !@git.master_branch_contains?(branch.sha) && (Time.now - branch.updated_at < two_weeks) }
      current_rereres = current_branches.map { |branch| branch.resolutions.to_h.values }.flatten

      @git.commit_rerere(current_rereres)
    end

    def two_weeks
      60 * 60 * 24 * 14
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
          branch_not_merged = "ERROR: Your branch did not merge to #{@git.merge_branch}. Run 'flash_flow --resolve', fix the merge conflict(s) and then re-run this script\n"
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

    def in_shadow_repo
      ShadowRepo.new(@git, logger: logger).in_dir do
        yield
      end
    end

    def fetch(remote)
      @fetched_remotes ||= {}
      unless @fetched_remotes[remote]
        @git.fetch(remote)
        @fetched_remotes[remote] = true
      end
    end
  end
end
