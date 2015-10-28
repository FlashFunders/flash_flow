require 'logger'

require 'flash_flow/git'

module FlashFlow
  class ShadowRepo


    def initialize(git, opts={})
      @git = git
      @cmd_runner = CmdRunner.new(logger: opts[:logger])
    end

    def in_dir(opts={})
      opts = { reset: true, go_back: true }.merge(opts)
      create_shadow_repo

      Dir.chdir(flash_flow_dir) do
        @git.run("reset --hard HEAD") if opts[:reset]

        yield
      end
    end

    def create_shadow_repo
      unless Dir.exists?(flash_flow_dir)
        @cmd_runner.run("mkdir -p #{flash_flow_dir}")
        @cmd_runner.run("cp -R #{current_dir} #{flash_flow_base_dir}")
      end
    end

    def flash_flow_base_dir
      @flash_flow_base_dir ||= current_dir + "/../.flash_flow"
    end

    def current_dir
      @current_dir ||= Dir.getwd
    end

    def flash_flow_dir
      @flash_flow_dir ||= flash_flow_base_dir + "/#{File.basename(current_dir)}"
    end
  end
end

