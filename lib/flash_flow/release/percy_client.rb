require 'percy'
require 'flash_flow/git'
require 'flash_flow/mailer'
require 'flash_flow/release/pdf_diff_generator'
require 'flash_flow/google_drive'

module FlashFlow
  module Release
    class PercyClient

      def initialize(config={})
        @client = initialize_connection!(config)
        @git = ShadowGit.new(Config.configuration.git, Config.configuration.logger)
        @compliance_config = config['compliance']
      end

      def find_latest_by_sha(sha)
        response = get_builds
        commit = find_commit_by_sha(response, sha)
        find_build_by_commit_id(response, commit['id'])
      end

      def send_compliance_email
        begin
          max_wait_time = @compliance_config['max_wait_time'] || 0
          delay = @compliance_config['delay'] || 1
          build = find_completed_build_by_sha(get_latest_sha, max_wait_time, delay)

          if build.nil?
            -1
          else
            gen_compliance_pdf_file(build) if has_unapproved_diffs?(build)
            0
          end
        rescue Exception => e
          puts e.message
          -1
        end
      end

      def send_release_email
        build = find_latest_by_sha(get_latest_sha)

        if has_unapproved_diffs?(build)
          mailer.deliver!(:compliance, { percy_build_url: build['web-url'] })
        end
      end

      def gen_pdf_diffs(output_file, build_id=nil, threshold=0.0)
        # TODO: Switch this over to Percy.get_comparisons at some point
        build_id ||= get_build_id
        PdfDiffGenerator.new.generate(get_comparisons(build_id), output_file, threshold)
      end

      def qa_approved?(sha=nil)
        build = find_latest_by_sha(sha || get_latest_sha)
        !build['approved-at'].nil?
      end

      private

      def find_completed_build_by_sha(sha, max_wait_time=5, delay=1)
        max_wait_time *= 60
        delay *= 60
        build = find_latest_by_sha(sha)
        start_time = Time.now

        until build_completed?(build) do
          return nil if Time.now - start_time >= max_wait_time
          putc '#'
          sleep delay
          build = find_latest_by_sha(sha)
        end
        build
      end

      def gen_compliance_pdf_file(build)
        build_id = extract_build_id(build)
        base_file_name = gen_compliance_file_name(build_id)
        drive = GoogleDrive.new
        existing_files = drive.find_files("name contains '#{File.basename(base_file_name)}' and mimeType = 'application/pdf'")

        if existing_files.empty?
          file_name = "#{base_file_name}_#{Time.now.strftime('%Y%m%dT%H%M')}.pdf"
          gen_pdf_diffs(file_name, build_id)

          puts "Uploading #{file_name} to Google Drive"
          drive.upload_file(file_name, @compliance_config.merge({ email_body: compose_compliance_email_body(build) }))
        else
          puts "This build has already been processed: #{existing_files.first.name}."
        end
      end

      def gen_compliance_file_name(build_id)
        "/tmp/#{@compliance_config['file_prefix']}#{build_id}"
      end

      def compose_compliance_email_body(build)
        @compliance_config['message'].sub('%percy_url%', build['web-url'])
      end

      def get_build_id(sha=nil)
        build = find_latest_by_sha(sha || get_latest_sha)
        extract_build_id(build)
      end

      def extract_build_id(build)
        build['web-url'].split('/').last
      end

      def initialize_connection!(config)
        if config['token'].nil?
          raise RuntimeError.new('Percy token must be set in your flash flow config.')
        end

        Percy.client.config.access_token = config['token']
        Percy.client.config.repo = config['repo'] unless config['repo'].nil?
        Percy.client
      end

      def get_comparisons(build_id)
        @client.get("#{Percy.config.api_url}/builds/#{build_id}/comparisons")
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
          .select do |h|
          h['type'] == 'builds' &&
            h.dig('attributes', 'web-url') &&
            h.dig('relationships', 'commit', 'data', 'type') == 'commits'
        end
      end

      def commits_data(response)
        response.fetch('included', { 'id' => nil })
          .select { |data| data['type'] == 'commits' }
      end

      def has_unapproved_diffs?(build)
        build['total-comparisons-diff'] > 0 && build['approved-at'].nil?
      end

      def build_completed?(build)
        build['state'] === 'finished';
      end

      def get_latest_sha
        @git.get_sha(@git.release_branch)
      end

      def mailer
        @mailer ||= FlashFlow::Mailer::Base.new(Config.configuration.smtp)
      end

    end
  end
end
