require 'flash_flow/data/base'
require 'flash_flow/git'
require 'flash_flow/release/percy_client'

module FlashFlow
  module Release
    class QAError < RuntimeError;
    end

    class Base
      def initialize(config=nil)
        release_class_name = config && config['class'] && config['class']['name']
        return unless release_class_name

        @git = ShadowGit.new(Config.configuration.git, Config.configuration.logger)
        @data = Data::Base.new({}, Config.configuration.branch_info_file, @git, logger: logger)

        @release_class = Object.const_get(release_class_name)
        @release = @release_class.new(config['class'].merge({ 'release_sha' => release_sha }))
      end

      def find_latest_by_sha(sha)
        @release.find_latest_by_sha(sha) if @release.respond_to?(:find_latest_by_sha)
      end

      def send_compliance_email
        @release.send_compliance_email if @release.respond_to?(:send_compliance_email) && pending_release?
      end

      def send_release_email
        @release.send_release_email if @release.respond_to?(:send_release_email)
      end

      def gen_pdf_diffs(output_file, threshold=0.0)
        @release.gen_pdf_diffs(output_file, threshold) if @release.respond_to?(:gen_pdf_diffs)
      end

      def qa_approved?(sha)
        @release.qa_approved?(sha) if @release.respond_to?(:qa_approved?)
      end

      private

      def pending_release?
        pending_release = @data.pending_release
        !pending_release.nil? && @git.ahead_of_master?("#{@git.remote}/#{@git.release_branch}")
      end

      def release_sha
        @git.get_sha("#{@git.remote}/#{@git.release_branch}")
      end

    end
  end
end
