require 'percy'
require 'flash_flow/git'
require 'flash_flow/mailer'

module FlashFlow
  module Release
    class PercyClient

      def initialize(config={})
        @client = initialize_connection!(config['token'])
        @git = ShadowGit.new(Config.configuration.git, Config.configuration.logger)
        @mailer = FlashFlow::Mailer::Base.new(Config.configuration.smtp)
      end

      def find_latest_by_sha(sha)
        response = get_builds
        commit = find_commit_by_sha(response, sha)
        find_build_by_commit_id(response, commit['id'])
      end

      def send_release_email
        build = find_latest_by_sha(get_latest_sha)

        if has_unapproved_diffs?(build)
          @mailer.deliver!(percy_build_url: build['web-url'])
        end
      end

      private

      def initialize_connection!(token)
        if token.nil?
          raise RuntimeError.new("Percy token must be set in your flash flow config.")
        end

        Percy.client.config.access_token = token
        Percy.client
      end

      def get_builds
        @client.get("#{Percy.config.api_url}/repos/#{Percy.config.repo}/builds/")
      end

      def find_commit_by_sha(response, sha)
        commits_data(response).detect { |h| h.dig('attributes', 'sha') == sha }
      end

      def find_build_by_commit_id(response, commit_id)
        builds_collection(response)
          .select { |b| b.dig('relationships', 'commit', 'data', 'id') == commit_id }
          .sort_by { |b| DateTime.parse(b.dig('attributes', 'created-at')) }.last
          &.fetch('attributes', {}) || {}
      end

      def builds_collection(response)
        response.fetch('data', [])
          .select do |h| h['type'] == 'builds' &&
            h.dig('attributes', 'web-url') &&
            h.dig('relationships', 'commit', 'data', 'type') == 'commits'
          end
      end

      def commits_data(response)
        response.fetch('included', {'id' => nil})
          .select { |data| data['type'] == 'commits' }
      end

      def has_unapproved_diffs?(build)
        build['total-comparisons-diff'] > 0 && !build['approved-at'].nil?
      end

      def get_latest_sha
        @git.in_branch(@git.release_branch) do
          @git.head_sha
        end
      end

    end
  end
end
