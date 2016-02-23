require 'octokit'
require 'flash_flow/data/branch'

module FlashFlow
  module Data
    class Github

      attr_accessor :repo, :unmergeable_label

      def initialize(config={})
        initialize_connection!(config['token'])
        @repo = config['repo']
        @master_branch = config['master_branch'] || master
        @unmergeable_label = config['unmergeable_label'] || 'unmergeable'
        @do_not_merge_label = config['do_not_merge_label'] || 'do not merge'
        @code_reviewed_label = config['code_reviewed_label'] || 'code reviewed'
      end

      def initialize_connection!(token)
        if token.nil?
          raise RuntimeError.new("Github token must be set in your flash_flow config file.")
        end
        octokit.configure do |c|
          c.access_token = token
        end
      end

      def remove_from_merge(branch)
        pr = pr_for(branch)
        if pr && @do_not_merge_label
          add_label(pr.number, @do_not_merge_label)
        end
      end

      def fetch
        pull_requests.map do |pr|
          Branch.from_hash(
              'remote_url' => pr.head.repo.ssh_url,
              'ref' => pr.head.ref,
              'status' => status_from_labels(pr),
              'metadata' => metadata(pr),
              'sha' => pr.head.sha
          )
        end
      end

      def add_to_merge(branch)
        pr = pr_for(branch)

        pr ||= create_pr(branch.ref, branch.ref, branch.ref)
        branch.add_metadata(metadata(pr))

        if pr && @do_not_merge_label
          remove_label(pr.number, @do_not_merge_label)
        end
      end

      def mark_success(branch)
        remove_label(branch.metadata['pr_number'], @unmergeable_label)
      end

      def mark_failure(branch)
        add_label(branch.metadata['pr_number'], @unmergeable_label)
      end

      def can_ship?(branch)
        has_label?(branch.metadata['pr_number'], @code_reviewed_label)
      end

      def branch_link(branch)
        branch.metadata['pr_url']
      end

      private

      def status_from_labels(pull_request)
        case
          when has_label?(pull_request.number, @do_not_merge_label)
            'removed'
          when has_label?(pull_request.number, @unmergeable_label)
            'fail'
          else
            nil
        end
      end

      def pr_for(branch)
        pull_requests.detect { |p| branch.remote_url == p.head.repo.ssh_url && branch.ref == p.head.ref }
      end

      def update_pr(pr_number)
        octokit.update_pull_request(repo, pr_number, {})
      end

      def create_pr(branch, title, body)
        pr = octokit.create_pull_request(repo, @master_branch, branch, title, body)
        pull_requests << pr
        pr
      end

      def pull_requests
        @pull_requests ||= octokit.pull_requests(repo).sort_by(&:created_at)
      end

      def remove_label(pull_request_number, label)
        if has_label?(pull_request_number, label)
          octokit.remove_label(repo, pull_request_number, label)
        end
      end

      def add_label(pull_request_number, label)
        unless has_label?(pull_request_number, label)
          octokit.add_labels_to_an_issue(repo, pull_request_number, [label])
        end
      end

      def has_label?(pull_request_number, label_name)
        !!labels(pull_request_number).detect { |label| label == label_name }
      end

      def labels(pull_request_number)
        @labels ||= {}
        @labels[pull_request_number] ||= octokit.labels_for_issue(repo, pull_request_number).map(&:name)
      end

      def metadata(pr)
        {
            'pr_number' => pr.number,
            'pr_url'    => pr.html_url,
            'user_url'  => pr.user.html_url,
            'repo_url'  => pr.head.repo.html_url
        }
      end

      def octokit
        Octokit
      end
    end
  end
end
