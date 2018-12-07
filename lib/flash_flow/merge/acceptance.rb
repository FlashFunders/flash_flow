require 'flash_flow/merge/base'
require 'flash_flow/time_helper'

module FlashFlow
  module Merge
    class Acceptance < Base

      def initialize(opts={})
        super(opts)

        @data = Data::Base.new(Config.configuration.branches, Config.configuration.branch_info_file, @git, logger: logger)

        @do_not_merge = opts[:do_not_merge]
        @force = opts[:force]
        @rerere_forget = opts[:rerere_forget]
        @stories = [opts[:stories]].flatten.compact
      end

      def run
        check_version
        check_git_version
        check_repo
        puts "Building #{@local_git.merge_branch}... Log can be found in #{FlashFlow::Config.configuration.log_file}"
        logger.info "\n\n### Beginning #{@local_git.merge_branch} merge ###\n\n"

        begin
          open_pull_request

          @lock.with_lock do
            @git.in_original_merge_branch do
              @git.initialize_rerere(@local_git.working_dir)
            end

            @git.reset_temp_merge_branch
            @git.in_temp_merge_branch do
              merge_branches(@data.mergeable) do |branch, merger|
                # Do not merge the master branch or the merge branch
                next if [@git.merge_branch, @git.master_branch].include?(branch.ref)
                process_result(branch, merger)
              end
              commit_branch_info
              commit_rerere
            end

            @git.copy_temp_to_branch(@git.merge_branch, commit_message)
            @git.delete_temp_merge_branch
            @git.push(@git.merge_branch)
          end

          raise OutOfSyncWithRemote.new("#{@git.merge_branch} is out of sync with the remote.") unless @git.last_success?
          print_errors
          logger.info "### Finished #{@local_git.merge_branch} merge ###"
        rescue Lock::Error, OutOfSyncWithRemote => e
          puts 'Failure!'
          puts e.message
        ensure
          @local_git.run("checkout #{@local_git.working_branch}")
        end
      end

      def commit_branch_info
        @stories.each do |story_id|
          @data.add_story(@git.working_branch, story_id)
        end
        @data.save!
      end

      def commit_rerere
        current_branches = @data.to_a.select { |branch| !@git.master_branch_contains?(branch.sha) && (Time.now - branch.updated_at < TimeHelper.two_weeks) }
        current_rereres = current_branches.map { |branch| branch.resolutions.to_h.values }.flatten

        @git.commit_rerere(current_rereres)
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

        @local_git.push(@local_git.working_branch, @force)
        raise OutOfSyncWithRemote.new("Your branch is out of sync with the remote. If you want to force push, run 'flash_flow -f'") unless @local_git.last_success?

        if @do_not_merge
          @data.remove_from_merge(@local_git.working_branch)
        else
          @data.add_to_merge(@local_git.working_branch)
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
            errors << "WARNING: Unable to merge branch #{@local_git.remote}/#{branch.ref} to #{@local_git.merge_branch} due to conflicts."
          end
        end
        errors << branch_not_merged if branch_not_merged

        if errors.empty?
          "Success!"
        else
          errors.join("\n")
        end
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
end
