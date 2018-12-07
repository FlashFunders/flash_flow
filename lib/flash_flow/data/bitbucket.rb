require 'tinybucket'
require 'flash_flow/data/branch'

module FlashFlow
  module Data
    class Bitbucket

      attr_accessor :repo, :unmergeable_label

      def initialize(config={})
        initialize_connection!(config['oauth_token'], config['oauth_secret'])
        @repo_owner = config['repo_owner']
        @repo = config['repo']
        @master_branch = config['master_branch'] || 'master'
        @unmergeable_label = config['unmergeable_label'] || 'Flash Flow -- Unmergeable'
        @do_not_merge_label = config['do_not_merge_label'] || 'Flash Flow -- Do Not Merge'
        # @code_reviewed_label = config['code_reviewed_label'] || 'code reviewed'
        # @shippable_label = config['shippable_label'] || 'shippable'
      end

      def initialize_connection!(oauth_token, oauth_secret)
        if oauth_token.nil? || oauth_secret.nil?
          raise RuntimeError.new("Oauth token and Oauth secret must be set in your flash_flow config file.")
        end
        Tinybucket.configure do |config|
          config.oauth_token = oauth_token
          config.oauth_secret = oauth_secret
        end
      end

      def remove_from_merge(branch)
        pr = pr_for(branch)
        if pr && @do_not_merge_label
          add_labeling(pr, @do_not_merge_label)
        end
      end

      def fetch
        pull_requests.map do |pr|
          Branch.from_hash(
              'ref' => pr.source['branch']['name'],
              'status' => status_from_labeling(pr),
              'metadata' => metadata(pr),
              'sha' => pr.source['commit']['hash']
          )
        end
      end

      def add_to_merge(branch)
        pr = pr_for(branch)

        pr ||= create_pr(branch.ref, branch.ref, branch.ref)
        branch.add_metadata(metadata(pr))

        if pr && @do_not_merge_label
          remove_labeling(pr, @do_not_merge_label)
        end
      end

      def mark_success(branch)
        remove_labeling(pr_for(branch), @unmergeable_label)
      end

      def mark_failure(branch)
        add_labeling(pr_for(branch), @unmergeable_label)
      end

      def code_reviewed?(branch)
        is_labeled?(pr_for(branch), @code_reviewed_label)
      end

      def can_ship?(branch)
        is_labeled?(pr_for(branch), @shippable_label)
      end

      def branch_link(branch)
        branch.metadata['pr_url']
      end

      private

      def status_from_labeling(pr)
        case
        when is_labeled?(pr, @do_not_merge_label)
            'removed'
          when is_labeled?(pr, @unmergeable_label)
            'fail'
          else
            nil
        end
      end

      def pr_for(branch)
        pull_requests.detect { |pr| branch.ref == pr.source['branch']['name'] }
      end

      def create_pr(branch, title, body)
        pr_resource = Tinybucket::Resource::PullRequests.new(repo_obj, [])
        pr = pr_resource.create(source: { branch: { name: branch }}, title: title, description: body)
        pull_requests << pr
        pr
      end

      def pull_requests
        @pull_requests ||= repo_obj.pull_requests.sort_by(&:created_on)
      end

      def labeling_string(label)
        " ---  #{label}"
      end

      def labeling_regex(label)
        /#{Regexp.escape(labeling_string(label))}$/
      end

      def remove_labeling(pr, label)
        if is_labeled?(pr, label)
          pr.title.gsub!(labeling_regex(label), '')
          pr.update
        end
      end

      def add_labeling(pr, label)
        unless is_labeled?(pr, label)
          pr.title += labeling_string(label)
          pr.update
        end
      end

      def is_labeled?(pr, label)
        pr.title =~ labeling_regex(label)
      end

      def metadata(pr)
        {
            'pr_number' => pr.id,
            'pr_url'    => pr.links['html']['href'],
            'user_url'  => pr.author['links']['html']['href'],
            'repo_url'  => repo_obj.links['html']['href']
        }
      end

      def repo_obj
        @repo_obj ||= begin
          repo = Tinybucket.new.repo(@repo_owner, @repo)
          repo.load
          repo
        end
      end
    end
  end
end
