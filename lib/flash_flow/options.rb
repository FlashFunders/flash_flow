require 'optparse'

module FlashFlow
  class Options
    def self.parse
      options = {}
      opt_parser = OptionParser.new do |opts|
        opts.banner = "Usage: flash_flow [options]"
        opts.separator ""

        opts.on('--install', 'Copy flash_flow.yml.erb to your repo and exit') { |v| options[:install] = true }
        opts.on('--prod-deploy', 'Run IssueTracker#deploy_production and exit') { |v| options[:prod_deploy] = true }
        opts.on('--review-deploy', 'Run IssueTracker#deploy_review and exit') { |v| options[:review_deploy] = true }
        opts.on('--release-notes hours', 'Run IssueTracker#release_notes and exit') { |v| options[:release_notes] = v }
        opts.on('-n', '--no-merge', 'Run flash flow, but do not merge this branch') { |v| options[:do_not_merge] = true }
        opts.on('--rerere-forget', 'Delete the saved patch for this branch and let the merge fail if there is a conflict') { |v| options[:rerere_forget] = true }
        opts.on('--story id1', 'story id for this branch') { |v| options[:stories] = [v] }
        opts.on('--stories id1,id2', 'comma-delimited list of story ids for this branch') { |v| options[:stories] = v.split(',') }
        opts.on('-f', '--force-push', 'Force push your branch') { |v| options[:force] = v }
        opts.on('-c', '--config-file FILE_PATH', 'The path to your config file. Defaults to config/flash_flow.yml.erb') { |v| options[:config_file] = v }
        opts.on('--resolve', 'Launch a bash shell to save your conflict resolutions') { |v| options[:resolve] = true }
        opts.on('--resolve-manual', 'Print instructions to use git to resolve conflicts') { |v| options[:resolve_manual] = true }

        opts.on_tail("-h", "--help", "Show this message") do
          puts opts
          exit
        end
      end

      opt_parser.parse!

      options[:stories] ||= []
      options[:config_file] ||= './config/flash_flow.yml.erb'

      options
    end
  end
end
