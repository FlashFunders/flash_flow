require 'octokit'

module FlashFlow
  class Github

    attr_accessor :repo, :unmergeable_label, :locking_issue_id

    def initialize(repo, opts={})
      initialize_connection!
      @repo = repo
      @unmergeable_label = opts[:unmergeable_label] || 'unmergeable'
      @locking_issue_id = opts[:locking_issue_id]
    end

    def initialize_connection!
      if ENV['GH_TOKEN'].nil?
        raise RuntimeError.new("Github token must be set in your environment via 'GH_TOKEN'.")
      end
      Octokit.configure do |c|
        c.access_token = ENV['GH_TOKEN']
      end
    end

    def with_lock(&block)
      locking_issue = Octokit.issue(repo, locking_issue_id)
      if locking_issue.state == 'open'
        raise RuntimeError.new('Someone else is running this script')
      else
        Octokit.reopen_issue(repo, locking_issue_id)
      end

      begin
        block.call
      ensure
        Octokit.close_issue(repo, locking_issue_id)
      end
    end

    def update_pr(repo, pr_number, opts)
      Octokit.update_pull_request(repo, pr_number, opts)
    end

    def create_pr(repo, base, branch, title, body)
      pull_requests << Octokit.create_pull_request(repo, base, branch, title, body)
    end

    def pull_requests
      @pull_requests ||= Octokit.pull_requests(repo).sort_by(&:created_at)
    end

    def remove_unmergeable_label(pull_request_number)
      if has_unmergeable_label?(pull_request_number)
        Octokit.remove_label(repo, pull_request_number, unmergeable_label)
      end
    end

    def add_unmergeable_label(pull_request_number)
      unless has_unmergeable_label?(pull_request_number)
        Octokit.add_labels_to_an_issue(repo, pull_request_number, [unmergeable_label])
      end
    end

    def has_unmergeable_label?(pull_request_number)
      Octokit.labels_for_issue(repo, pull_request_number).detect { |label| label.name == unmergeable_label }
    end
  end
end