require 'flash_flow/lock/github'

module FlashFlow
  module Lock
    class Error < RuntimeError; end

    class Base
      def initialize(config=nil)
        lock_class_name = config && config['class'] && config['class']['name']
        return unless lock_class_name

        lock_class = Object.const_get(lock_class_name)
        @lock = lock_class.new(config['class'])
      end

      def with_lock(&block)
        if @lock
          @lock.with_lock(&block)
        else
          yield
        end
      end
    end
  end
end
