require 'hipchat'

module FlashFlow
  class Hipchat

    def initialize(room)
      @client = initialize_connection!
      @room = room
    end

    def initialize_connection!
      if Config.configuration.hipchat_token.nil?
        raise RuntimeError.new("Hipchat token must be set in your environment via 'HIPCHAT_TOKEN'.")
      end

      hipchat_client.new(Config.configuration.hipchat_token, api_version: "v2")
    end

    def hipchat_client
      HipChat::Client
    end

    def notify_merge_conflict(pull_request_creator, repo_url, ref)
      pull_request_creator_link = %{<a href="#{pull_request_creator}">#{pull_request_creator.split('/').last}</a>}
      ref_link = %{<a href="#{repo_url}/tree/#{ref}">#{ref}</a>}

      message = %{#{pull_request_creator_link}'s branch (#{ref_link}) did not merge to acceptance successfully}
      @client[@room].send("FlashFlow", message)
    end
  end
end
