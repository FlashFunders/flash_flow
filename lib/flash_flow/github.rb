require 'octokit'

module FlashFlow
  class Github

    attr_accessor :repo, :unmergeable_label

    def initialize(repo, opts={})
      initialize_connection!
      @repo = repo
      @unmergeable_label = opts[:unmergeable_label] || 'unmergeable'
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
      locking_issue = octokit.issue(repo, issue_id)
      if locking_issue.state == 'open'
        raise RuntimeError.new('Someone else is running this script')
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