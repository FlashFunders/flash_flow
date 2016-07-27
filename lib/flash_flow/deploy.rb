require 'logger'

require 'flash_flow/git'
require 'flash_flow/data'
require 'flash_flow/lock'
require 'flash_flow/notifier'
require 'flash_flow/branch_merger'
require 'flash_flow/merge_order'
require 'flash_flow/shadow_repo'

module FlashFlow
  class Deploy

    class GitPushFailure < RuntimeError ; end
    class OutOfSyncWithRemote < RuntimeError ; end
    class UnmergeableBranch < RuntimeError ; end

    def initialize(opts={})
      @do_not_merge = opts[:do_not_merge]
      @force = opts[:force]
      @rerere_forget = opts[:rerere_forget]
      @stories = [opts[:stories]].flatten.compact

      @local_git = Git.new(Config.configuration.git, logger)
      @git = ShadowGit.new(Config.configuration.git, logger)
      @lock = Lock::Base.new(Config.configuration.lock)
      @notifier = Notifier::Base.new(Config.configuration.notifier)
      @data = Data::Base.new(Config.configuration.branches, Config.configuration.branch_info_file, @git, logger: logger)

      @release_branches = parse_branches(opts[:release_branches])
    end

    def logger
      @logger ||= FlashFlow::Config.configuration.logger
    end

    def parse_branches(user_branches)
      branch_list = user_branches == ['ready'] ? shippable_branch_names : [user_branches].flatten.compact

      branch_list.map { |b| Data::Branch.new('origin', @git.remotes_hash['origin'], b) }
    end

    def run_release
      check_version
      check_repo
      check_branches
      puts "Merging these branches into #{@git.release_branch}:\n  #{@release_branches.map(&:ref).join("\n  ")}"
      logger.info "\n\n### Beginning #{@local_git.merge_branch} merge ###\n\n"

      begin
        mergers, errors = [], []

        @lock.with_lock do
          @git.fetch(@git.merge_remote)
          @git.in_original_merge_branch do
            @git.initialize_rerere
          end

          @git.reset_temp_merge_branch
          @git.in_temp_merge_branch do
            merge_branches(@release_branches) do |branch, merger|
              mergers << [branch, merger]
            end
          end

          errors = mergers.select { |m| m.last.result != :success }

          if errors.empty?
            @git.copy_temp_to_branch(@git.release_branch)
            @git.delete_temp_merge_branch
            unless @git.push(@git.release_branch, false)
              raise GitPushFailure.new("Unable to push to #{@git.release_branch}. See log for details.")
            end
          end
        end

        if errors.empty?
          puts 'Success!'
        else
          raise UnmergeableBranch.new("The following branches didn't merge successfully:\n  #{errors.map {|e| e.first.ref }.join("\n  ")}")
        end

        logger.info "### Finished #{@git.release_branch} merge ###"
      rescue Lock::Error, OutOfSyncWithRemote, UnmergeableBranch, GitPushFailure => e
        puts 'Failure!'
        puts e.message
      ensure
        @local_git.run("checkout #{@local_git.working_branch}")
      end
    end

    def run
      check_version
      check_repo
      puts "Building #{@local_git.merge_branch}... Log can be found in #{FlashFlow::Config.configuration.log_file}"
      logger.info "\n\n### Beginning #{@local_git.merge_branch} merge ###\n\n"

      begin
        open_pull_request

        @lock.with_lock do
          @git.fetch(@git.merge_remote)
          @git.in_original_merge_branch do
            @git.initialize_rerere
          end

          @git.reset_temp_merge_branch
          @git.in_temp_merge_branch do
            merge_branches(@data.merged_branches.mergeable) do |branch, merger|
              process_result(branch, merger)
            end
            commit_branch_info
            commit_rerere
          end

          @git.copy_temp_to_branch(@git.merge_branch, commit_message)
          @git.delete_temp_merge_branch
          @git.push(@git.merge_branch, true)
        end

        print_errors
        logger.info "### Finished #{@local_git.merge_branch} merge ###"
      rescue Lock::Error, OutOfSyncWithRemote => e
        puts 'Failure!'
        puts e.message
      ensure
        @local_git.run("checkout #{@local_git.working_branch}")
      end
    end

    def check_branches
      requested_not_ready_branches = (@release_branches.map(&:ref) - shippable_branch_names)
      raise RuntimeError.new("The following branches are not ready to ship:\n#{requested_not_ready_branches.join("\n")}") unless requested_not_ready_branches.empty?
    end

    def shippable_branch_names
      @shippable_branch_names ||= begin
        status = MergeMaster::Status.new(Config.configuration.issue_tracker, Config.configuration.branches, Config.configuration.branch_info_file, Config.configuration.git, logger: logger)

        all_branches = status.branches
        all_branches.values.select { |b| b[:shippable?] }.map { |b| b[:name] }
      end
    end

    def check_repo
      if @local_git.staged_and_working_dir_files.any?
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

    def merge_branches(branches)
      ordered_branches = MergeOrder.new(@git, branches).get_order
      ordered_branches.each_with_index do |branch, index|
        branch.merge_order = index + 1

        remote = @git.fetch_remote_for_url(branch.remote_url)
        if remote.nil?
          raise RuntimeError.new("No remote found for #{branch.remote_url}. Please run 'git remote add *your_remote_name* #{branch.remote_url}' and try again.")
        end

        @git.fetch(branch.remote)
        merger = git_merge(branch)

        yield(branch, merger)
      end
    end

    def git_merge(branch)
      merger = BranchMerger.new(@git, branch)
      forget_rerere = is_working_branch(branch) && @rerere_forget

      merger.do_merge(forget_rerere)

      merger
    end

    def process_result(branch, merger)
      case merger.result
        when :deleted
          @data.mark_deleted(branch)
          @notifier.deleted_branch(branch) unless is_working_branch(branch)

        when :success
          branch.sha = merger.sha
          @data.mark_success(branch)
          @data.set_resolutions(branch, merger.resolutions)

        when :conflict
          if is_working_branch(branch)
            @data.mark_failure(branch, merger.conflict_sha)
          else
            @data.mark_failure(branch, nil)
            @notifier.merge_conflict(branch)
          end
      end
    end

    def is_working_branch(branch)
      branch.ref == @git.working_branch
    end

    def open_pull_request
      return false if [@local_git.master_branch, @local_git.merge_branch].include?(@local_git.working_branch)

      # TODO - This should use the actual remote for the branch we're on
      @local_git.push(@local_git.working_branch, @force)
      raise OutOfSyncWithRemote.new("Your branch is out of sync with the remote. If you want to force push, run 'flash_flow -f'") unless @local_git.last_success?

      # TODO - This should use the actual remote for the branch we're on
      if @do_not_merge
        @data.remove_from_merge(@local_git.merge_remote, @local_git.working_branch)
      else
        @data.add_to_merge(@local_git.merge_remote, @local_git.working_branch)
      end
    end

    def print_errors
      puts format_errors
    end

    def format_errors
      errors = []
      branch_not_merged = nil
      @data.failures.each do |branch|
        if branch.ref == @local_git.working_branch
          branch_not_merged = "ERROR: Your branch did not merge to #{@local_git.merge_branch}. Run 'flash_flow --resolve', fix the merge conflict(s) and then re-run this script\n"
        else
          errors << "WARNING: Unable to merge branch #{branch.remote}/#{branch.ref} to #{@local_git.merge_branch} due to conflicts."
        end
      end
      errors << branch_not_merged if branch_not_merged

      if errors.empty?
        "Success!"
      else
        errors.join("\n")
      end
    end

    def release_commit_message
      message =<<-EOS
Flash Flow merged these branches:
#{@release_branches.map(&:ref).join("\n")}
      EOS
      message.gsub(/'/, '')
    end

    def commit_message
      message =<<-EOS
Flash Flow run from branch: #{@local_git.working_branch}

Merged branches:
#{@data.successes.empty? ? 'None' : @data.successes.sort_by(&:merge_order).map(&:ref).join("\n")}

Failed branches:
#{@data.failures.empty? ? 'None' : @data.failures.map(&:ref).join("\n")}

Removed branches:
#{@data.removals.empty? ? 'None' : @data.removals.map(&:ref).join("\n")}
      EOS
      message.gsub(/'/, '')
    end

  end
end