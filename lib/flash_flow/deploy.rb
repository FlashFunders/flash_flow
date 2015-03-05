require 'logger'

require 'flash_flow/cmd_runner'
require 'flash_flow/github'
require 'flash_flow/git'

module FlashFlow
  class Deploy

    attr_reader :cmd_runner, :branch, :pull_requests, :merge_successes, :merge_errors, :pr_title, :pr_body, :force

    def initialize(opts={})
      @pr_title = opts[:pr_title]
      @pr_body = opts[:pr_body]
      @force = opts[:force]

      @cmd_runner = CmdRunner.new(opts.merge(logger: logger))
      @github = Github.new(Config.configuration.repo, unmergeable_label: Config.configuration.unmergeable_label, locking_issue_id: Config.configuration.locking_issue_id)
      @git = Git.new(@cmd_runner, Config.configuration.merge_branch, Config.configuration.master_branch, Config.configuration.use_rerere)
      check_repo
      @working_branch = @git.current_branch
      @merge_branch = FlashFlow::Config.configuration.merge_branch
      @merge_successes, @merge_errors = [], []
    end

    def logger
      @logger ||= FlashFlow::Config.configuration.logger
    end

    def run
      puts "Building #{@merge_branch}... Log can be found in #{FlashFlow::Config.configuration.log_file}"
      logger.info "\n\n### Beginning #{@merge_branch} merge ###\n\n"

      @git.fetch_origin
      @git.initialize_rerere
      @github.with_lock do
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
    end

    def check_repo
      if @git.staged_and_working_dir_files.any?
        raise RuntimeError.new('You have changes in your working directory. Please stash and try again')
      end
    end

    def write_branch_info
      File.open(Config.configuration.branch_info_file, 'w') do |f|
        if merge_successes.empty?
          f.puts "== No merged branches"
        else
          f.puts "== Merged branches"
          merge_successes.each do |ref|
            f.puts ref
            f.puts
          end
        end

        f.puts

        if merge_errors.empty?
          f.puts "== No merge failures"
        else
          f.puts "== Pull requested branches that didn't merge"
          merge_errors.each do |ref|
            f.puts ref
            f.puts
          end
        end
      end
    end

    def commit_branch_info
      write_branch_info
      @git.add_and_commit(Config.configuration.branch_info_file, 'Branch Info', add: { force: true })
    end

    def merge_pull_requests
      @github.pull_requests.each do |pull_request|
        merge_or_rollback(pull_request.head.ref, pull_request.number)
      end
    end

    def open_pull_request
      @git.push(@working_branch, force: @force)
      raise "Failed to push code: '#{@git.last_command}'" unless @git.last_success?

      pr = @github.pull_requests.detect { |p| p.head.ref == @working_branch }
      if pr
        opts = { title: @pr_title, body: @pr_body }.delete_if { |k,v| v.to_s == '' }

        @github.update_pr(Config.configuration.repo, pr.number, opts) unless opts.empty?
      else
        @github.create_pr(Config.configuration.repo, Config.configuration.master_branch, @working_branch, (@pr_title || @working_branch),
                          (@pr_body || @working_branch))
      end
    end

    def print_errors
      errors = []
      branch_not_merged = nil
      merge_errors.each do |b|
        if b == @working_branch
          branch_not_merged = "\nERROR: Your branch did not merge to #{@git.merge_branch}. Run the following commands to fix the merge conflict and then re-run this script:\n\n  git checkout #{merge_branch}\n  git merge #{@working_branch}\n  # Resolve the conflicts\n  git add <conflicted files>\n  git commit --no-edit"
        else
          errors << "WARNING: Unable to merge branch #{b} to #{merge_branch} due to conflicts."
        end
      end
      errors << branch_not_merged if branch_not_merged

      if errors.empty?
        puts "Success!"
      else
        puts errors.join("\n")
      end
    end

    def merge_or_rollback(ref, pull_request_number, fix_conflicts=true)
      @git.run("merge origin/#{ref}")

      if @git.last_success?
        merge_successes << ref
        @github.remove_unmergeable_label(pull_request_number)
      elsif @git.rerere_resolve!
        merge_successes << ref
        @github.remove_unmergeable_label(pull_request_number)
      elsif fix_conflicts
        fix_translations
        return merge_or_rollback(ref, pull_request_number, false)
      else
        merge_errors << ref
        @git.run("reset --hard HEAD")
        @github.add_unmergeable_label(pull_request_number)
      end
    end

    def fix_translations
      @cmd_runner.run('bundle exec rake i18n:js:export')
      @git.run('add app/assets/javascripts/i18n/translations.js')
      @git.run('commit --no-edit')
    end

  end
end

