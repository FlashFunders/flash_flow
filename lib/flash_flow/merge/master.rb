require 'flash_flow/merge/base'

module FlashFlow
  module Merge
    class Master < Base

      class GitPushFailure < RuntimeError; end
      class OutOfSyncWithRemote < RuntimeError; end
      class UnmergeableBranch < RuntimeError; end

      def initialize(opts={})
        super(opts)

        @release_branches = parse_branches(opts[:release_branches])
      end

      def run
        check_version
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
              unless @git.push(@git.release_branch, true)
                raise GitPushFailure.new("Unable to push to #{@git.release_branch}. See log for details.")
              end
            end
          end

          if errors.empty?
            puts 'Success!'
          else
            raise UnmergeableBranch.new("The following branches didn't merge successfully:\n  #{errors.map { |e| e.first.ref }.join("\n  ")}")
          end

          logger.info "### Finished #{@git.release_branch} merge ###"
        rescue Lock::Error, OutOfSyncWithRemote, UnmergeableBranch, GitPushFailure => e
          puts 'Failure!'
          puts e.message
        ensure
          @local_git.run("checkout #{@local_git.working_branch}")
        end
      end

      def parse_branches(user_branches)
        branch_list = user_branches == ['ready'] ? shippable_branch_names : [user_branches].flatten.compact

        branch_list.map { |b| Data::Branch.new('origin', @git.remotes_hash['origin'], b) }
      end

      def check_branches
        requested_not_ready_branches = (@release_branches.map(&:ref) - shippable_branch_names)
        raise RuntimeError.new("The following branches are not ready to ship:\n#{requested_not_ready_branches.join("\n")}") unless requested_not_ready_branches.empty?
      end

      def shippable_branch_names
        @shippable_branch_names ||= begin
          status = Merge::Status.new(Config.configuration.issue_tracker, Config.configuration.branches, Config.configuration.branch_info_file, Config.configuration.git, logger: logger)

          all_branches = status.branches
          all_branches.values.select { |b| b[:shippable?] }.map { |b| b[:name] }
        end
      end

      def commit_message
        message =<<-EOS
Flash Flow merged these branches:
#{@release_branches.map(&:ref).join("\n")}
        EOS
        message.gsub(/'/, '')
      end

    end
  end
end