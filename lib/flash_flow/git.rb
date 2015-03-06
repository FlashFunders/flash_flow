module FlashFlow
  class Git
    attr_reader :merge_branch, :master_branch, :use_rerere

    UNMERGED_STATUSES = %w{DD AU UD UA DU AA UU}

    def initialize(cmd_runner, merge_branch, master_branch, use_rerere)
      @cmd_runner = cmd_runner
      @merge_branch = merge_branch
      @master_branch = master_branch
      @working_branch = current_branch
      @use_rerere = use_rerere
    end

    def last_stdout
      @cmd_runner.last_stdout
    end

    def last_command
      @cmd_runner.last_command
    end

    def last_success?
      @cmd_runner.last_success?
    end

    def run(cmd)
      @cmd_runner.run("git #{cmd}")
    end

    def add_and_commit(files, message, opts={})
      files = [files].flatten
      run("add #{'-f ' if opts[:add] && opts[:add][:force]}#{files.join(' ')}")
      run("commit -m '#{message}'")
    end

    def push(branch, options)
      run("push #{'-f' if options[:force]} origin #{branch}")
    end

    def merge(branch)
      run("merge #{branch}")
    end

    def fetch_origin
      run("fetch origin")
    end

    def initialize_rerere
      return unless use_rerere

      @cmd_runner.run('mkdir .git/rr-cache')
      run("checkout origin/#{merge_branch}")
      @cmd_runner.run('cp -R rr-cache/* .git/rr-cache/')
    end

    def commit_rerere
      return unless use_rerere
      @cmd_runner.run('mkdir rr-cache')
      @cmd_runner.run('cp -R .git/rr-cache/* rr-cache/')
      run('add rr-cache/')
      run("commit -m 'Update rr-cache'")
    end

    def rerere_resolve!
      return false unless use_rerere

      merging_files = staged_and_working_dir_files.select { |s| UNMERGED_STATUSES.include?(s[0..1]) }.map { |s| s[3..-1] }

      conflicts = merging_files.map do |file|
        File.open(file) { |f| f.grep(/>>>>/) }
      end

      if conflicts.all? { |c| c.empty? }
        run("add #{merging_files.join(" ")}")
        run('commit --no-edit')
        true
      else
        false
      end
    end

    def staged_and_working_dir_files
      run("status --porcelain")
      last_stdout.split("\n").reject { |line| line[0..1] == '??' }
    end

    def current_branch
      run("rev-parse --abbrev-ref HEAD")
      last_stdout.strip
    end

    def checkout_merge_branch
      run("fetch origin")
      run("branch -D #{merge_branch}")
      run("checkout -b #{merge_branch}")
      run("reset --hard origin/#{master_branch}")
    end

    def push_merge_branch
      run("push -f origin #{merge_branch}")
    end

    def in_merge_branch(&block)
      checkout_merge_branch

      begin
        block.call
      ensure
        run("checkout #{@working_branch}")
      end
    end
  end
end