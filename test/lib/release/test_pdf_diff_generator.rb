require 'minitest_helper'
require 'flash_flow/release/pdf_diff_generator'

module FlashFlow
  module Release
    class TestPdfDiffGenerator < Minitest::Test

      def test_gen_pdf_diffs
        # PdfDiffGenerator.new.generate(compare_response, '/tmp/test_build_diffs.pdf', 0.0, false)
      end

      private

      def compare_response
        file = File.read('test/fixtures/pdf_diff_test_1.json')
        JSON.parse(file)
      end
    end
  end
end

