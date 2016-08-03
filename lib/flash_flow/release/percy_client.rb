require 'percy'

module FlashFlow
  module Release
    class PercyClient

      def initialize(config={})
        @client = initialize_connection!(config['token'])
      end

      def find_latest_by_sha(sha)
        response = get_builds
        commit = find_commit_by_sha(response, sha)
        build = find_build_by_commit_id(response, commit['id'])

        { url: build['web-url'], approved: !build['approved-at'].nil? }
      end

      private

      def initialize_connection!(token)
        if token.nil?
          raise RuntimeError.new("Percy token must be set in your flash flow config.")
        end

        Percy.client.config.access_token = token
        percy_client
      end

      def percy_client
        Percy.client
      end

      def get_builds
        @client.get("#{Percy.config.api_url}/repos/#{Percy.config.repo}/builds/")
      end

      def find_commit_by_sha(response, sha)
        commits_data(response).detect { |h| h.dig('attributes', 'sha') == sha }
      end

      def find_build_by_commit_id(response, commit_id)
        builds = builds_collection(response)
        return if builds.nil?

        latest_build = builds
          .select { |b| b.dig('relationships', 'commit', 'data', 'id') == commit_id }
          .sort_by { |b| DateTime.parse(b.dig('attributes', 'created-at')) }.last

        latest_build['attributes']
      end

      def builds_collection(response)
        response['data'].select do |h|
          h['type'] == 'builds' &&
            h.dig('attributes', 'web-url') &&
            h.dig('relationships', 'commit', 'data', 'type') == 'commits'
        end
      end

      def commits_data(response)
        response['included'].select { |data| data['type'] == 'commits' }
      end

    end
  end
end
