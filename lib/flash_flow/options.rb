require 'optparse'

module FlashFlow
  class Options
    attr_accessor :ff_branch, :br_branch, :story_id, :working_dir, :dry_run

    def self.parse
      options = {}
      opt_parser = OptionParser.new do |opts|
        opts.banner = "Usage: #{__FILE__} [options]"

        opts.on('-n', '--no-merge', 'Run flash flow, but do not merge this branch') { |v| options[:do_not_merge] = true }
        opts.on('', '--story id1', 'story id for this branch') { |v| options[:stories] = [v] }
        opts.on('', '--stories id1,id2', 'comma-delimited list of story ids for this branch') { |v| options[:stories] = v.split(',') }
        opts.on('-f', '--force-push', 'Force push your branch') { |v| options[:force] = v }
        opts.on('-c', '--config-file FILE_PATH', 'The path to your config file. Defaults to config/flash_flow.yml') { |v| options[:config_file] = v }
        opts.on('-X', '--dry-run', 'Show the commands that will be run') { |v| options[:dry_run] = v }

        opts.on_tail("-h", "--help", "Show this message") do
          puts opts
          exit
        end
      end

      opt_parser.parse!

      options[:stories] ||= []
      options[:config_file] ||= './config/flash_flow.yml'

      options
    end
  end
end
