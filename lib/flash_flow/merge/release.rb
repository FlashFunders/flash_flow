require 'flash_flow/merge/base'

module FlashFlow
  module Merge
    class Release < Base

      class PendingReleaseError < RuntimeError; end
      class GitPushFailure < RuntimeError; end

      def initialize(opts={})
        super(opts)

        @force = opts[:force]
        @release_branches = parse_branches(opts[:release_branches])

        @data = Data::Base.new({}, Config.configuration.branch_info_file, @git, logger: logger)

        @release_branches.each {|b| b.merge_order = @data.collection.get(b.ref).merge_order }
      end

      def run
        begin
          check_version
          check_branches
          puts "Merging these branches into #{@git.release_branch}:\n  #{@release_branches.map(&:ref).join("\n  ")}"
          logger.info "\n\n### Beginning #{@local_git.merge_branch} merge ###\n\n"

          mergers, errors = [], []

          @lock.with_lock do
            release = pending_release
            if release
              raise PendingReleaseError.new("There is already a pending release: #{release}")
            elsif release_ahead_of_master?
              raise PendingReleaseError.new("The release branch '#{@git.release_branch}' has commits that are not in master")
            end

            initialize_rerere

            @git.reset_temp_merge_branch
            @git.in_temp_merge_branch do
              merge_branches(@release_branches) do |branch, merger|
                mergers << [branch, merger]
              end
            end

            errors = mergers.select { |m| m.last.result != :success }

            if errors.empty?
              unless @git.push("#{@git.temp_merge_branch}:#{@git.release_branch}", true)
                raise GitPushFailure.new("Unable to push to #{@git.release_branch}. See log for details.")
              end

              release_sha = @git.get_sha(@git.temp_merge_branch)

              @data.releases.unshift({ created_at: Time.now, sha: release_sha, status: 'Pending' })

              write_data('Release branch created [ci skip]')
            end
          end

          if errors.empty?
            puts 'Success!'
          else
            raise UnmergeableBranch.new("The following branches didn't merge successfully:\n  #{errors.map { |e| e.first.ref }.join("\n  ")}")
          end

          logger.info "### Finished #{@git.release_branch} merge ###"
        rescue Lock::Error, OutOfSyncWithRemote, UnmergeableBranch, GitPushFailure, NothingToMergeError, VersionError, PendingReleaseError => e
          puts 'Failure!'
          puts e.message
        ensure
          @local_git.run("checkout #{@local_git.working_branch}")
        end
      end

      def parse_branches(user_branches)
        branch_list = user_branches == ['ready'] ? shippable_branch_names : [user_branches].flatten.compact

        branch_list.map { |b| Data::Branch.new(b) }
      end

      def check_branches
        raise NothingToMergeError.new("Nothing to merge") if @release_branches.empty?

        unless @force
          requested_not_ready_branches = (@release_branches.map(&:ref) - shippable_branch_names)
          raise RuntimeError.new("The following branches are not ready to ship:\n#{requested_not_ready_branches.join("\n")}") unless requested_not_ready_branches.empty?
        end
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
