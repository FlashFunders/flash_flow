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

    def notify_merge_conflict(branch)
      user_name = branch.metadata['user_url'].split('/').last
      user_url_link = %{<a href="#{branch.metadata['user_url']}">#{user_name}</a>}
      ref_link = %{<a href="#{branch.metadata['repo_url']}/tree/#{branch.ref}">#{branch.ref}</a>}

      message = %{#{user_url_link}'s branch (#{ref_link}) did not merge to acceptance successfully}
      # @client[@room].send("FlashFlow", message)
    end
  end
end
