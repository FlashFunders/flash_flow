require 'mail'

module FlashFlow
  module Mailer
    class Base

      def initialize(config)
        unless config&.fetch('settings', false)
          raise RuntimeError.new("smtp settings must be set in your flash flow config.")
        end

        configure!(config['settings'])
      end

      def deliver!(type, data={})
        delivery_info = get_delivery_info(type)

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

      def get_delivery_info(email_type)
        Config.configuration.smtp.dig("emails", email_type.to_s)
      end

    end
  end
end
