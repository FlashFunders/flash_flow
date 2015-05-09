require 'logger'

require 'flash_flow/cmd_runner'
require 'flash_flow/github'
require 'flash_flow/git'
require 'flash_flow/branch_info'
require 'flash_flow/lock'
require 'flash_flow/hipchat'

module FlashFlow
  class Deploy

    class OutOfSyncWithRemote < RuntimeError ; end

    attr_reader :cmd_runner, :branch, :pull_requests, :pr_title, :pr_body, :force

    def initialize(opts={})
      @pr_title = opts[:pr_title]
      @pr_body = opts[:pr_body]
      @force = opts[:force]

      @cmd_runner = CmdRunner.new(opts.merge(logger: logger))
      @github = Github.new(Config.configuration.repo, unmergeable_label: Config.configuration.unmergeable_label)
      @merge_remote = FlashFlow::Config.configuration.merge_remote
      @merge_branch = FlashFlow::Config.configuration.merge_branch
      @git = Git.new(@cmd_runner, @merge_remote, @merge_branch, Config.configuration.master_branch, Config.configuration.use_rerere)
      @working_branch = @git.current_branch
      @lock = Lock::Base.new(Config.configuration.lock)
      @hipchat = Hipchat.new('Engineering')
      @branch_info = BranchInfo.new
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
            merge_pull_requests
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
          @branch_info.add_story(@merge_remote, @working_branch, story_id)
        end
        BranchInfoStore.new(Config.configuration.branch_info_file, @git, logger: logger).merge_and_save(@branch_info.branches)
        @git.add_and_commit(Config.configuration.branch_info_file, 'Branch Info', add: { force: true })
      end
    end

    def merge_pull_requests
      @github.pull_requests.each do |pull_request|
        remotes = @git.fetch_remotes_for_url(pull_request.head.repo.ssh_url)
        remote = (Config.configuration.remotes & remotes).first
        if remote.nil?
          raise RuntimeError.new("No remote found for #{pull_request.head.repo.ssh_url}. Please run 'git remote add *your_remote_name* #{pull_request.head.repo.ssh_url}' and try again.")
        end

        unless @github.has_label?(pull_request.number, Config.configuration.do_not_merge_label)
          pull_request_info = {ref: pull_request.head.ref, number: pull_request.number, user_url: pull_request.user.html_url, repo_url: pull_request.head.repo.html_url}
          git_merge(remote, pull_request_info)
        end
      end
    end

    def git_merge(remote, pull_request_info)
      ref = pull_request_info[:ref]
      pull_request_number = pull_request_info[:number]

      if merge_success?(remote, ref)
        @branch_info.mark_success(remote, ref)
        @github.remove_unmergeable_label(pull_request_number)
      else
        @branch_info.mark_failure(remote, ref)
        @github.add_unmergeable_label(pull_request_number)
        @hipchat.notify_merge_conflict(pull_request_info[:user_url], pull_request_info[:repo_url], ref) unless working_pull_request
      end
    end

    def working_pull_request
      @github.pull_requests.detect { |p| p.head.ref == @working_branch }
    end

    def open_pull_request
      return false if [Config.configuration.master_branch, @merge_branch].include?(@working_branch)

      @git.push(@working_branch, force: @force)
      raise OutOfSyncWithRemote.new("Your branch is out of sync with the remote. If you want to force push, run 'flash_flow -f'") unless @git.last_success?

      pr = working_pull_request
      if pr
        opts = { title: @pr_title, body: @pr_body }.delete_if { |k,v| v.to_s == '' }

        @github.update_pr(Config.configuration.repo, pr.number, opts) unless opts.empty?
      else
        @github.create_pr(Config.configuration.repo, Config.configuration.master_branch, @working_branch, (@pr_title || @working_branch),
                          (@pr_body || @working_branch))
      end
    end

    def print_errors
      puts format_errors
    end

    def format_errors
      errors = []
      branch_not_merged = nil
      @branch_info.failures.each do |full_ref, failure|
        if failure['branch'] == @working_branch
          branch_not_merged = "\nERROR: Your branch did not merge to #{@git.merge_branch}. Run the following commands to fix the merge conflict and then re-run this script:\n\n  git checkout #{@git.merge_branch}\n  git merge #{@working_branch}\n  # Resolve the conflicts\n  git add <conflicted files>\n  git commit --no-edit"
        else
          errors << "WARNING: Unable to merge branch #{full_ref} to #{@git.merge_branch} due to conflicts."
        end
      end
      errors << branch_not_merged if branch_not_merged

      if errors.empty?
        "Success!"
      else
        errors.join("\n")
      end
    end

    def merge_success?(remote, ref, fix_conflicts=true)
      fetch(remote)

      @git.run("merge #{remote}/#{ref}")

      if @git.last_success? || @git.rerere_resolve!
        return true
      elsif fix_conflicts
        fix_translations
        return merge_success?(remote, ref, false)
      else
        @git.run("reset --hard HEAD")
        return false
      end
    end

    def fix_translations
      @cmd_runner.run('bundle exec rake i18n:js:export')
      @git.run('add app/assets/javascripts/i18n/translations.js')
      @git.run('commit --no-edit')
    end
  end
end
