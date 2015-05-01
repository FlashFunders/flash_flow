require 'action_view'
require 'action_view/helpers'
include ActionView::Helpers::DateHelper
require 'flash_flow/github'
require 'flash_flow/lock'

module FlashFlow
  class GithubLock < Lock
    attr_accessor :repo

    def initialize(repo)
      @github = Github.new(repo)
    end

    def with_lock(issue_id, &block)
      return block.call if issue_id.nil?

      if @github.issue_open?(issue_id)
        last_event = @github.get_last_event(issue_id)
        actor = last_event[:actor][:login]
        time = time_ago_in_words(last_event[:created_at])
        issue_link = "https://github.com/#{repo}/issues/#{issue_id}"

        raise Lock::Error.new(error_message(actor, issue_link, time))
      else
        @github.open_issue(issue_id)

        begin
          block.call
        ensure
          @github.close_issue(issue_id)
        end
      end
    end

    def error_message(actor, issue_link, time)
      "#{actor} started running flash_flow #{time} ago. To unlock flash_flow,
        go here: <#{issue_link}> and close the issue and re-run flash_flow."
    end
  end
end
