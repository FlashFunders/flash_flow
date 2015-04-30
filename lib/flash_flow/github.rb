require 'octokit'
require 'byebug'
require 'action_view'
require 'action_view/helpers'
include ActionView::Helpers::DateHelper
require 'flash_flow/git'

module FlashFlow
  class Github

    attr_accessor :repo, :unmergeable_label

    def initialize(repo, opts={})
      initialize_connection!
      @repo = repo
      @unmergeable_label = opts[:unmergeable_label] || 'unmergeable'
      @cmd_runner = CmdRunner.new(opts.merge(logger: logger))
      @working_branch = current_branch
    end

    def logger
      @logger ||= FlashFlow::Config.configuration.logger
    end

    def current_branch
      @cmd_runner.run("git rev-parse --abbrev-ref HEAD")
      @cmd_runner.last_stdout.strip
    end

    def initialize_connection!
      if ENV['GH_TOKEN'].nil?
        raise RuntimeError.new("Github token must be set in your environment via 'GH_TOKEN'.")
      end
      octokit.configure do |c|
        c.access_token = ENV['GH_TOKEN']
      end
    end

    def open_issue(issue_id)
      octokit.issue_events(repo, issue_id)
      last_issue_events_page = octokit.last_response.rels[:last].get
      locking_issue = last_issue_events_page.data.last

      if locking_issue.event == 'reopened'
        actor = locking_issue[:actor][:login]
        time = time_ago_in_words(locking_issue[:created_at])
        issue_link = "https://github.com/#{repo}/issues/#{issue_id}"

        @cmd_runner.run("git checkout #{@working_branch}")
        raise RuntimeError.new("#{actor} started running flash_flow #{time} ago.
          To unlock flash_flow, go here: <#{issue_link}> and close the issue and re-run flash_flow.")
      else
        octokit.reopen_issue(repo, issue_id)
      end
    end

    def with_lock(issue_id, &block)
      return block.call if issue_id.nil?

      open_issue(issue_id)

      begin
        block.call
      ensure
        octokit.close_issue(repo, issue_id)
      end
    end

    def update_pr(repo, pr_number, opts)
      octokit.update_pull_request(repo, pr_number, opts)
    end

    def create_pr(repo, base, branch, title, body)
      pull_requests << octokit.create_pull_request(repo, base, branch, title, body)
    end

    def pull_requests
      @pull_requests ||= octokit.pull_requests(repo).sort_by(&:created_at)
    end

    def remove_unmergeable_label(pull_request_number)
      if has_unmergeable_label?(pull_request_number)
        octokit.remove_label(repo, pull_request_number, unmergeable_label)
      end
    end

    def add_unmergeable_label(pull_request_number)
      unless has_unmergeable_label?(pull_request_number)
        octokit.add_labels_to_an_issue(repo, pull_request_number, [unmergeable_label])
      end
    end

    def has_unmergeable_label?(pull_request_number)
      octokit.labels_for_issue(repo, pull_request_number).detect { |label| label.name == unmergeable_label }
    end

    def octokit
      Octokit
    end
  end
end
