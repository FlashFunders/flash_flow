require 'flash_flow/branch'
require 'flash_flow/notifier/hipchat'

module FlashFlow
  module Notifier
    class Base
      def initialize(config=nil)
        notifier_class_name = config && config['class'] && config['class']['name']
        return unless notifier_class_name

        @notifier_class = Object.const_get(notifier_class_name)
        @notifier = @notifier_class.new(config['class'])
      end

      def merge_conflict(branch)
        @notifier.merge_conflict(branch) if @notifier.respond_to?(:merge_conflict)
      end

      def deleted_branch(branch)
        @notifier.deleted_branch(branch) if @notifier.respond_to?(:deleted_branch)
      end
    end
  end
end
