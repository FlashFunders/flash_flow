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
        :use_rerere, :merge_remote, :merge_branch, :master_branch, :repo,
        :branch_info_file, :unmergeable_label, :do_not_merge_label, :log_file,
        :remotes, :hipchat_token, :issue_tracker, :lock, :branches
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
          use_rerere: true,
          merge_remote: 'origin',
          merge_branch: 'acceptance',
          master_branch: 'master',
          branch_info_file: 'README.rdoc',
          unmergeable_label: 'unmergeable',
          do_not_merge_label: 'do not merge',
          log_file: 'log/flash_flow.log',
          remotes: ['origin'],
          hipchat_token: ENV['HIPCHAT_TOKEN'],
          issue_tracker: nil,
          lock: nil,
          branches: nil,
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
