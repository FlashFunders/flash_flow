require 'logger'
require 'singleton'
require 'yaml'
require 'erb'

module FlashFlow
  class Config

    class AlreadyConfigured < StandardError ; end
    class NotYetConfigured < StandardError ; end
    class IncompleteConfiguration < StandardError ; end

    include Singleton
    class << self
      private :instance
    end

    ATTRIBUTES = [
      :git, :branch_info_file, :log_file, :notifier, :issue_tracker, :lock, :branches, :release, :smtp
    ]

    attr_reader *ATTRIBUTES
    attr_reader :logger

    def self.configuration
      raise NotYetConfigured unless instance.instance_variable_get(:@configured)
      instance
    end

    def self.configure!(config_file)
      raise AlreadyConfigured if instance.instance_variable_get(:@configured)

      template = ERB.new File.read(config_file)
      yaml = YAML.load template.result(binding)
      config = defaults.merge(symbolize_keys!(yaml))

      missing_attrs = []
      ATTRIBUTES.each do |attr_name|
        missing_attrs << attr_name unless config.has_key?(attr_name)
        instance.instance_variable_set("@#{attr_name}", config[attr_name])
      end

      instance.instance_variable_set(:@logger, Logger.new(instance.log_file))

      raise IncompleteConfiguration.new("Missing attributes:\n #{missing_attrs.join("\n ")}") unless missing_attrs.empty?

      instance.instance_variable_set(:@configured, true)
    end

    def self.defaults
      {
          branch_info_file: 'README.rdoc',
          log_file: 'log/flash_flow.log',
          notifier: nil,
          issue_tracker: nil,
          lock: nil,
          branches: nil,
          release: nil,
          smtp: nil
      }
    end

    def self.symbolize_keys!(hash)
      hash.keys.each do |k|
        unless k.is_a?(Symbol)
          hash[k.to_sym] = hash[k]
          hash.delete(k)
        end
      end
      hash
    end
  end
end
