require 'mail'

module FlashFlow
  module Mailer
    class Base

      def initialize(config)
        configure!(config['settings']) unless config['settings'].nil?
      end

      def deliver!(data={})
        delivery_info = Config.configuration.smtp["emails"]

        if delivery_info
          delivery_info["body_html"] = body_html(data, delivery_info["body_file"])

          Mail.deliver do
            from     delivery_info["from"]
            to       delivery_info["to"]
            cc       delivery_info["cc"]
            subject  delivery_info["subject"]
            body     delivery_info["body_html"]
          end
        end
      end

      private

      def configure!(config)
        Mail.defaults { delivery_method :smtp, config.symbolize_keys }
      end

      def body_html(data, template)
        @data = data
        erb_template = ERB.new File.read(template)
        erb_template.result(binding)
      end

    end
  end
end
