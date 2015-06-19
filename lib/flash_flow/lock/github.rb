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
        if issue_open?
          raise Lock::Error.new(error_message)
        else
          open_issue

          begin
            block.call
          ensure
            close_issue
          end
        end
      end

      private

      def error_message
        last_event = get_last_event
        actor = last_event[:actor][:login]
        time = last_event[:created_at]
        issue_link = "https://github.com/#{repo}/issues/#{issue_id}"
        minutes_ago = ((Time.now - time).to_i / 60) rescue 'unknown'

        "#{actor} started running flash_flow #{minutes_ago} minutes ago. To manually unlock flash_flow, go here: #{issue_link} and close the issue and re-run flash_flow."
      end

      def get_last_event
        Octokit.issue_events(repo, issue_id).last.rels[:self].get.data
      end

      def issue_open?
        get_last_event.event == 'reopened'
      end

      def open_issue
        Octokit.reopen_issue(repo, issue_id)
      end

      def close_issue
        Octokit.close_issue(repo, issue_id)
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
    end
  end
end