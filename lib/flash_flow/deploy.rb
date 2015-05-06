require 'logger'

require 'flash_flow/cmd_runner'
require 'flash_flow/github'
require 'flash_flow/github_lock'
require 'flash_flow/git'
require 'flash_flow/branch_info'
require 'flash_flow/lock'
require 'flash_flow/hipchat'

module FlashFlow
  class Deploy

    class OutOfSyncWithRemote < RuntimeError ; end

    attr_reader :cmd_runner, :branch, :pull_requests, :merge_successes, :merge_errors, :pr_title, :pr_body, :force

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
      @merge_successes, @merge_errors = [], []
      @github_lock = GithubLock.new(Config.configuration.repo)
      @hipchat = Hipchat.new('Thailand')
    end

    def logger
      @logger ||= FlashFlow::Config.configuration.logger
    end

    def run
      check_repo
      puts "Building #{@merge_branch}... Log can be found in #{FlashFlow::Config.configuration.log_file}"
      logger.info "\n\n### Beginning #{@merge_branch} merge ###\n\n"

      fetch(@merge_remote)
      @git.initialize_rerere
      begin
        @github_lock.with_lock(Config.configuration.locking_issue_id) do
          open_pull_request

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
        BranchInfo.write(Config.configuration.branch_info_file, merge_successes, merge_errors)
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
          merge_or_rollback(remote, pull_request)
        end
      end
    end

    def working_pull_request
      @github.pull_requests.detect { |p| p.head.ref == @working_branch }
    end

    def open_pull_request
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
      merge_errors.each do |r, b|
        if b == @working_branch
          branch_not_merged = "\nERROR: Your branch did not merge to #{@git.merge_branch}. Run the following commands to fix the merge conflict and then re-run this script:\n\n  git checkout #{@git.merge_branch}\n  git merge #{@working_branch}\n  # Resolve the conflicts\n  git add <conflicted files>\n  git commit --no-edit"
        else
          errors << "WARNING: Unable to merge branch #{r}/#{b} to #{@git.merge_branch} due to conflicts."
        end
      end
      errors << branch_not_merged if branch_not_merged

      if errors.empty?
        "Success!"
      else
        errors.join("\n")
      end
    end

    def merge_or_rollback(remote, pull_request, fix_conflicts=true)
      fetch(remote)

      ref = pull_request.head.ref
      pull_request_number = pull_request.number
      @git.run("merge #{remote}/#{ref}")

      if @git.last_success?
        merge_successes << [remote, ref]
        @github.remove_unmergeable_label(pull_request_number)
      elsif @git.rerere_resolve!
        merge_successes << [remote, ref]
        @github.remove_unmergeable_label(pull_request_number)
      elsif fix_conflicts
        fix_translations
        return merge_or_rollback(remote, ref, pull_request_number, false)
      else
        merge_errors << [remote, ref]
        @git.run("reset --hard HEAD")
        @github.add_unmergeable_label(pull_request_number)
        @hipchat.notify_merge_conflict(pull_request.user.html_url, pull_request.head.repo.html_url, ref) unless working_pull_request
      end
    end

    def fix_translations
      @cmd_runner.run('bundle exec rake i18n:js:export')
      @git.run('add app/assets/javascripts/i18n/translations.js')
      @git.run('commit --no-edit')
    end
  end
end
