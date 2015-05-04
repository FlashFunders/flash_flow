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

    def get_last_event(issue_id)
      octokit.issue_events(repo, issue_id)
      last_issue_events_page = octokit.last_response.rels[:last].get
      last_issue_events_page.data.last
    end

    def issue_open?(issue_id)
      get_last_event(issue_id).event == 'reopened'
    end

    def open_issue(issue_id)
      octokit.reopen_issue(repo, issue_id)
    end

    def close_issue(issue_id)
      octokit.close_issue(repo, issue_id)
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
