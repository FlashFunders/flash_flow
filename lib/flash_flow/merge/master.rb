require 'flash_flow/merge/base'
require 'flash_flow/release'

module FlashFlow
  module Merge
    class Master < Base

      class GitPushFailure < RuntimeError; end

      def initialize(opts={})
        super(opts)

        @data = Data::Base.new({}, Config.configuration.branch_info_file, @git, logger: logger)
      end

      def send_mail
        check_version
        check_git_version
        puts "Checking #{@git.release_branch} QA approval"
        logger.info "\n\n### Beginning check of #{@git.release_branch} QA ###\n\n"

        @lock.with_lock do
          release = pending_release
          ready!(release)

          send_release_ready_email(release)
        end

        logger.info "### Sent release email ###"
      rescue Lock::Error, NothingToMergeError, FlashFlow::Release::QAError, VersionError => e
        puts 'Failure!'
        puts e.message
      ensure
        @local_git.run("checkout #{@local_git.working_branch}")
      end

      def run
        begin
          check_version
          check_git_version
          puts "Merging #{@git.release_branch} into #{@git.master_branch}"
          logger.info "\n\n### Beginning merge of #{@git.release_branch} into #{@git.master_branch} ###\n\n"

          errors = []

          @lock.with_lock do
            release = pending_release || ready_to_merge_release
            ready!(release)

            errors = merge_master(release)
          end

          if errors.empty?
            puts 'Success!'
          else
            raise UnmergeableBranch.new("#{@git.release_branch} didn't merge successfully to #{@git.master_branch}:\n  #{errors.map { |e| e.first.ref }.join("\n  ")}")
          end

          logger.info "### Finished merge of #{@git.release_branch} into #{@git.master_branch} ###"
        rescue Lock::Error, OutOfSyncWithRemote, UnmergeableBranch, GitPushFailure, NothingToMergeError, FlashFlow::Release::QAError, VersionError => e
          puts 'Failure!'
          puts e.message
        ensure
          @local_git.run("checkout #{@local_git.working_branch}")
        end
      end

      def merge_master(release)
        @git.in_original_merge_branch do
          @git.initialize_rerere
        end

        mergers = []

        @git.in_branch(@git.master_branch) do
          @git.run("reset --hard origin/master")
          merge_branches([Data::Branch.new(@git.release_branch)]) do |branch, merger|
            mergers << [branch, merger]
          end
        end

        errors = mergers.select { |m| m.last.result != :success }

        if errors.empty?
          unless @git.push("#{@git.master_branch}:#{@git.master_branch}", true)
            raise GitPushFailure.new("Unable to push to #{@git.master_branch}. See log for details.")
          end

          release['status'] = 'Success'
          release['released_sha'] = @git.get_sha("#{@git.remote}/#{@git.master_branch}")
          write_data('Release info updated [ci skip]')
        end

        errors
      end

      def ready!(release)
        if !release
          raise NothingToMergeError.new("There is no pending release.")
        elsif !release_ahead_of_master?
          raise NothingToMergeError.new("The release branch '#{@git.release_branch}' has no commits that are not in master")
        elsif !release_qa_approved?
          raise FlashFlow::Release::QAError.new("The release build '#{get_release_sha(short: true)}' has not been approved for release")
        end
      end

      def release_qa_approved?
        release = FlashFlow::Release::Base.new(FlashFlow::Config.configuration.release)
        release.qa_approved?(get_release_sha)
      end

      def send_release_ready_email(release)
        begin
          mailer = FlashFlow::Mailer::Base.new(Config.configuration.smtp)
          mailer.deliver!(:release_ready, { approved_sha: get_release_sha(short: true) })

          release['status'] = 'Ready to merge'
          write_data('Release info updated [ci skip]')
        rescue ArgumentError => e
          raise FlashFlow::Release::QAError.new("Cannot send the email: #{e}")
        end
      end

      def get_release_sha(opts={})
        @get_release_sha ||= @git.get_sha("#{@git.remote}/#{@git.release_branch}", opts)
      end

    end
  end
end
