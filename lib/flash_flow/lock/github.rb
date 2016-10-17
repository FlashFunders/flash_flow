require 'octokit'

module FlashFlow
  module Lock
    class Github

      attr_reader :config
      private :config

      def initialize(config)
        @config = config

        verify_params!
        initialize_connection!
      end

      def with_lock(&block)
        if issue_locked?
          raise Lock::Error.new(error_message)
        else
          lock_issue

          begin
            block.call
          ensure
            unlock_issue
          end
        end
      end

      private

      def error_message
        issue_link = "https://github.com/#{repo}/issues/#{issue_id}"

        "flash_flow is running and locked by #{actor}. To manually unlock flash_flow, go here: #{issue_link} and remove the #{locked_label} label and re-run flash_flow."
      end

      def issue_locked?
        get_lock_labels.detect {|label| label[:name] == locked_label}
      end

      def lock_issue
        Octokit.add_labels_to_an_issue(repo, issue_id, [actor, locked_label])
      end

      def unlock_issue
        Octokit.remove_all_labels(repo, issue_id)
      end

      def get_lock_labels
        begin
          Octokit.labels_for_issue(repo, issue_id)
        rescue Octokit::NotFound
          []
        end
      end

      def verify_params!
        unless token && repo && issue_id
          raise Lock::Error.new("Github token, repo, and issue_id must all be set to use the Github lock.")
        end
      end

      def initialize_connection!
        Octokit.configure do |c|
          c.access_token = token
        end
      end

      def token
        config['token']
      end

      def repo
        config['repo']
      end

      def issue_id
        config['issue_id']
      end

      def locked_label
        config['lock_label'] || 'IS_LOCKED'
      end

      def actor
        @user_login ||= Octokit.user.login
      end
    end
  end
end
