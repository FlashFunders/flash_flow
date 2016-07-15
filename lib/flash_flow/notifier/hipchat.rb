require 'hipchat'

module FlashFlow
  module Notifier
    class Hipchat

      def initialize(config={})
        @client = initialize_connection!(config['token'])
        @room = config['room']
      end

      def merge_conflict(branch)
        begin
          user_name = branch.metadata['user_url'].split('/').last
          user_url_link = %{<a href="#{branch.metadata['user_url']}">#{user_name}</a>}
          ref_link = %{<a href="#{branch.metadata['repo_url']}/tree/#{branch.ref}">#{branch.ref}</a>}

          message = %{#{user_url_link}'s branch (#{ref_link}) did not merge successfully}
          @client[@room].send("FlashFlow", message)
        rescue HipChat::UnknownResponseCode => e
          puts e.message
        end
      end

      private

      def initialize_connection!(token)
        if token.nil?
          raise RuntimeError.new("Hipchat token must be set in your flash flow config.")
        end

        hipchat_client.new(token, api_version: "v2")
      end

      def hipchat_client
        HipChat::Client
      end
    end
  end
end
