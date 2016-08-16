require 'minitest_helper'
require 'flash_flow/release/pdf_diff_generator'
require 'fileutils'
require 'open-uri'

module FlashFlow
  module Release
    class TestPdfDiffGenerator < Minitest::Test

      def test_gen_pdf_diffs
        PdfDiffGenerator.new.generate(compare_response, '/tmp/test_build_diffs.pdf', 0.0, false)
      end

      def test_convert_response
        # localize_resources('test/fixtures/pdf_diff_test_1.json', 'test/fixtures/pdf_diff/')
      end

      private

      def compare_response
        file = File.read('test/fixtures/pdf_diff/pdf_diff_test_1.json')
        JSON.parse(file)
      end

      def localize_resources(source_file, location, threshold=0.0)
        pdf_generator = PdfDiffGenerator.new
        source_data = File.read(source_file)
        source_json = JSON.parse(source_data)
        info = pdf_generator.send(:collect_comparison_info, source_json, threshold)

        create_destination(location)

        info.each do |row|
          %w(head-screenshot base-screenshot pdiff).each do |attr|
            source_url = row.dig(attr, :url)
            target = File.join(location, "#{source_url.split('/').last}.png")
            # Copy the file locally if it doesn't exist
            unless File.exists?(target)
              open(target, 'wb') do |file|
                file << open(source_url).read
              end
            end
            # Use our local copy instead of the remote url
            source_data.sub(source_url, target)
          end
        end

        # Write out our new test data with only local references
        target = File.join(location, File.basename(source_file))
        open(target, 'w') { |file| file << source_data } unless File.exists?(target)
      end

      def create_destination(location)
        unless File.directory?(location)
          FileUtils.mkdir_p(location)
        end
      end

    end
  end
end

