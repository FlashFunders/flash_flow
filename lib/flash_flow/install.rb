require 'fileutils'

module FlashFlow
  class Install
    def self.install
      FileUtils.mkdir 'config' unless Dir.exists?('config')
      dest_file = 'config/flash_flow.yml.erb'

      FileUtils.cp example_file, dest_file

      puts "Flash flow config file is in #{dest_file}"
    end

    def self.example_file
      "#{File.dirname(__FILE__)}/../../flash_flow.yml.erb.example"
    end

  end
end