require 'logger'

require 'flash_flow/git'
require 'flash_flow/data'
require 'flash_flow/lock'
require 'flash_flow/notifier'
require 'flash_flow/branch_merger'
require 'flash_flow/merge_order'
require 'flash_flow/shadow_repo'

module FlashFlow
  module Merge
    class Base

      class VersionError < RuntimeError; end
      class OutOfSyncWithRemote < RuntimeError; end
      class UnmergeableBranch < RuntimeError; end
      class NothingToMergeError < RuntimeError; end

      def initialize(opts={})
        @local_git = Git.new(Config.configuration.git, logger)
        @git = ShadowGit.new(Config.configuration.git, logger)
        @lock = Lock::Base.new(Config.configuration.lock)
        @notifier = Notifier::Base.new(Config.configuration.notifier)
      end

      def logger
        @logger ||= FlashFlow::Config.configuration.logger
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

      def merge_branches(branches)
        ordered_branches = MergeOrder.new(@git, branches).get_order
        ordered_branches.each_with_index do |branch, index|
          branch.merge_order = index + 1

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

      def is_working_branch(branch)
        branch.ref == @git.working_branch
      end

      def pending_release
        @data.releases.detect { |r| r['status'] == 'Pending' }
      end

      def release_ahead_of_master
        @git.branch_exists?("#{@git.remote}/#{@git.release_branch}") &&
            !@git.branch_contains?(@git.master_branch, @git.get_sha("#{@git.remote}/#{@git.release_branch}"))
      end

      def write_data(commit_msg)
        @git.in_temp_merge_branch do
          @git.run("reset --hard #{@git.remote}/#{@git.merge_branch}")
        end
        @git.in_merge_branch do
          @git.run("reset --hard #{@git.remote}/#{@git.merge_branch}")
        end

        @data.save!

        @git.copy_temp_to_branch(@git.merge_branch, commit_msg)
        @git.delete_temp_merge_branch
        @git.push(@git.merge_branch, false)
      end

    end
  end
end