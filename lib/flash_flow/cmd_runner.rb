require 'logger'
require 'open3'

module FlashFlow
  class CmdRunner
    attr_reader :dry_run, :dir, :last_command, :last_stderr, :last_stdout

    def initialize(opts={})
      @dir = opts[:dir] || '.'
      @dry_run = opts[:dry_run]
      @logger = opts[:logger] || Logger.new('/dev/null')
    end

    def run(cmd)
      @last_command = cmd
      if dry_run
        puts "#{dir}$ #{cmd}"
        ''
      else
        Dir.chdir(dir) do
          Open3.popen3(cmd) do |_, stdout, stderr, wait_thr|
            @last_stdout = stdout.read
            @last_stderr = stderr.read
            @success = wait_thr.value.success?
          end
        end
        @logger.debug("#{dir}$ #{cmd}")
        last_stdout.split("\n").each { |line| @logger.debug(line) }
        last_stderr.split("\n").each { |line| @logger.debug(line) }
      end
    end

    def last_success?
      @success
    end
  end
end