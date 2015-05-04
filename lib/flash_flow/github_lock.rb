require 'flash_flow/github'
require 'flash_flow/lock'

module FlashFlow
  class GithubLock < Lock
    attr_accessor :repo

    def initialize(repo, github = nil)
      @github = github || Github.new(repo)
      @repo = repo
    end

    def with_lock(issue_id, &block)
      return block.call if issue_id.nil?

      if @github.issue_open?(issue_id)
        raise Lock::Error.new(error_message(issue_id))
      else
        @github.open_issue(issue_id)

        begin
          block.call
        ensure
          @github.close_issue(issue_id)
        end
      end
    end

    def error_message(issue_id)
      last_event = @github.get_last_event(issue_id)
      actor = last_event[:actor][:login]
      time = last_event[:created_at]
      issue_link = "https://github.com/#{repo}/issues/#{issue_id}"
      minutes_ago = ((Time.now - time).to_i / 60) rescue 'unknown'

      "#{actor} started running flash_flow #{minutes_ago} minutes ago. To manually unlock flash_flow, go here: #{issue_link} and close the issue and re-run flash_flow."
    end
  end
end
