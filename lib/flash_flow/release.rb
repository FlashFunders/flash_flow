require 'flash_flow/release/percy_client'

module FlashFlow
  module Release
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

    end
  end
end
