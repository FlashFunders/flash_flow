require 'prawn'
require 'open-uri'

module FlashFlow
  module Release
    class PdfDiffGenerator

      NUM_COLUMNS = 3
      SPACE_BETWEEN = 10

      def generate(compare_data, filename, threshold, verbose=true)
        info = collect_comparison_info(compare_data, threshold)
        @orientation = :portrait
        Prawn::Document.generate(filename, page_layout: @orientation, margin: [10, 10, 10, 10]) do |pdf|
          set_dimensions(*pdf.bounds.top_right)
          generate_title_page(pdf)
          info.each do |comparison|
            add_comparison_to_pdf(pdf, comparison)
          end
          pdf.number_pages('<page> of <total>', { start_count_at: 1, align: :right, size: 12 })
          @num_pages = pdf.page_count
        end
        puts "Wrote #{@num_pages} pages to: #{filename}" if verbose
        filename
      end

      private

      ##########################
      #                        #
      # PDF Generation methods #
      #                        #
      ##########################

      def set_dimensions(width, height)
        @page_width = width
        @page_height = height
        @column_landscape = compute_column_width([width, height].max)
        @column_portrait = compute_column_width([width, height].min)
      end

      def compute_column_width(page_width)
        (page_width / NUM_COLUMNS) - (SPACE_BETWEEN * (NUM_COLUMNS - 1))
      end

      def generate_title_page(pdf)
        pdf.text("Compliance Diffs Generated At: #{Time.now.to_s}")
      end

      def compute_scale_factor(column_width, page_height, width, height)
        x_scale_factor = column_width / width
        y_scale_factor = page_height / height
        [x_scale_factor, y_scale_factor].min
      end

      def compute_scale_and_orientation(width, height)
        scale_portrait = compute_scale_factor(@column_portrait, [@page_width, @page_height].max, width, height)
        scale_landscape = compute_scale_factor(@column_landscape, [@page_width, @page_height].min, width, height)
        if scale_portrait > scale_landscape
          @orientation = :portrait
          @column_width = @column_portrait
          scale_portrait
        else
          @orientation = :landscape
          @column_width = @column_landscape
          scale_landscape
        end
      end

      def max_width(comparison)
        max_by(comparison, :width)
      end

      def max_height(comparison)
        max_by(comparison, :height)
      end

      def max_by(comparison, key)
        [comparison['head-screenshot'][key], comparison['base-screenshot'][key], comparison['diff-image'][key]].max
      end

      def add_comparison_to_pdf(pdf, comparison)
        scale_factor = compute_scale_and_orientation(max_width(comparison), max_height(comparison))
        options = { vposition: :top, scale: scale_factor }

        pdf.start_new_page(layout: @orientation)
        place_image(pdf, comparison.dig('base-screenshot', :url), options, 1)
        place_image(pdf, comparison.dig('head-screenshot', :url), options, 2)
        place_image(pdf, comparison.dig('base-screenshot', :url), options, 3)
        place_image(pdf, comparison.dig('diff-image', :url), options, 3)
      end

      def place_image(pdf, url, options, column)
        pdf.float do
          options[:position] = (column - 1) * (@column_width + SPACE_BETWEEN)
          pdf.image(get_url_once(url), options)
        end
      end

      def get_url_once(url)
        @already_gotten_urls ||= {}
        @already_gotten_urls[url] ||= open(url)
      end

      ####################################
      #                                  #
      # Methods to traverse Percy output #
      #                                  #
      ####################################

      def collect_comparison_info(compare_info, threshold=0.0)
        compare_info['data']
            .select { |record| record['type'] == 'comparisons' }
            .map { |record| get_comparison_info(record, compare_info) }
            .select { |record| record&.dig('diff-ratio').to_f > threshold }
            .sort { |a, b| b['diff-ratio'] <=> a['diff-ratio'] }
      end

      def get_comparison_info(record, data)
        { id: record['id'] }.tap do |h|
          %w(head-screenshot base-screenshot diff-image).each do |attr|
            info = record.dig('relationships', attr, 'data')
            unless info.nil?
              attr_record = lookup_record(info['id'], info['type'], 'included', data)
              h[attr] = lookup_image_url(lookup_image_id(attr_record, attr), data)
              h['diff-ratio'] = record.dig('attributes', 'diff-ratio') if attr == 'diff-image'
            end
          end
        end
      end

      def lookup_image_id(record, attr)
        if attr == 'diff-image'
          record['id']
        else
          record.dig('relationships', 'image', 'data', 'id')
        end
      end

      def lookup_image_url(id, data)
        record = lookup_image(id, data)
        unless record.nil?
          { url: record.dig('attributes', 'url'),
            width: record.dig('attributes', 'width'),
            height: record.dig('attributes', 'height') }
        end
      end

      def lookup_comparison(id, data)
        lookup_record(id, 'comparisons', 'data', data)
      end

      def lookup_image(id, data)
        lookup_record(id, 'images', 'included', data)
      end

      def lookup_screenshot(id, data)
        lookup_record(id, 'screenshots', 'data', data)
      end

      def lookup_snapshot(id, data)
        lookup_record(id, 'snapshots', 'data', data)
      end

      def lookup_record(id, kind, where, data)
        data[where].detect { |item| item['type'] == kind && item['id'] == id }
      end

    end
  end
end
