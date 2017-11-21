require 'logger'

require 'flash_flow/git'

module FlashFlow
  class ShadowGit < Git

    def initialize(config, logger=nil)
      super

      create_shadow_repo
      @cmd_runner.dir = flash_flow_dir

      run("clean -x -f")
      run("fetch #{remote}")
      run("remote prune #{remote}")
      run("reset --hard HEAD")

      @repo = Rugged::Repository.new(flash_flow_dir)
    end

    def create_shadow_repo
      unless Dir.exists?(flash_flow_dir)
        @cmd_runner.run("mkdir -p #{flash_flow_dir}")
        @cmd_runner.run("cp -R #{current_dir} #{flash_flow_base_dir}")
      end
    end

    FLASH_FLOW_BASE = '.flash_flow'
    def flash_flow_base_dir
      if current_dir =~ /\.flash_flow/
        "#{current_dir.split(FLASH_FLOW_BASE).first}#{FLASH_FLOW_BASE}"
      else
        "#{current_dir}/../#{FLASH_FLOW_BASE}"
      end
    end

    def current_dir
      Dir.getwd
    end

    def flash_flow_dir
      @flash_flow_dir ||= flash_flow_base_dir + "/#{File.basename(current_dir)}"
    end
  end
end

