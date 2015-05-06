require 'minitest'
require 'minitest/autorun'
require 'flash_flow'

ENV['GH_TOKEN'] = 'fake_token'

class Minitest::Test

  class TestCmdRunner < Minitest::Mock
    def initialize(opts={}); super(); end
    def run(_); end
    def last_success?
      true
    end
    def last_stdout; ''; end
    def last_stderr; ''; end
    def last_command; ''; end
  end

  FlashFlow::CmdRunner = TestCmdRunner

  def reset_config!
    config = FlashFlow::Config.send(:instance)

    config.instance_variables.each do |i|
      config.remove_instance_variable(i)
    end
  end

  def config!(config_hash)
    reset_config!

    YAML.stub(:load_file, config_hash) do
      FlashFlow::Config.configure!('fake_file.txt')
    end
  end

end
