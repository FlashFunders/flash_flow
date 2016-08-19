require 'flash_flow/release/percy_client'

module FlashFlow
  module Release
    class QAError < RuntimeError; end

    class Base
      def initialize(config=nil)
        release_class_name = config && config['class'] && config['class']['name']
        return unless release_class_name

        @release_class = Object.const_get(release_class_name)
        @release = @release_class.new(config['class'])
      end

      def find_latest_by_sha(sha)
        @release.find_latest_by_sha(sha) if @release.respond_to?(:find_latest_by_sha)
      end

      def send_compliance_email
        @release.send_compliance_email if @release.respond_to?(:send_compliance_email)
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

    end
  end
end
