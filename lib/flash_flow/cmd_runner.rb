require 'logger'
require 'open3'

module FlashFlow
  class CmdRunner
    LOG_NONE = :log_none
    LOG_CMD = :log_cmd

    attr_reader :dry_run, :last_command, :last_stderr, :last_stdout
    attr_accessor :dir

    def initialize(opts={})
      @dir = opts[:dir] || '.'
      @dry_run = opts[:dry_run]
      @logger = opts[:logger] || Logger.new('/dev/null')
    end

    def run(cmd, opts={})
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
        log(cmd, opts[:log])
      end
    end

    def last_success?
      @success
    end

    private

    def log(cmd, log_what)
      log_what = nil
      if log_what == LOG_NONE
          # Do nothing
      else
          @logger.debug("#{dir}$ #{cmd}")
        unless log_what == LOG_CMD
          last_stdout.split("\n").each { |line| @logger.debug(line) }
          last_stderr.split("\n").each { |line| @logger.debug(line) }
        end
      end
    end
  end
end