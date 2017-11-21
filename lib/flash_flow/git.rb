require 'flash_flow/cmd_runner'
require 'shellwords'
require 'rugged'

module FlashFlow
  class Git
    ATTRIBUTES = [:remote, :merge_branch, :master_branch, :release_branch, :use_rerere]

    attr_reader(*ATTRIBUTES)
    attr_reader :working_branch, :repo

    UNMERGED_STATUSES = %w{DD AU UD UA DU AA UU}

    def initialize(config, logger=nil)
      @cmd_runner = CmdRunner.new(logger: logger)
      @repo = Rugged::Repository.new(@cmd_runner.dir)

      config['release_branch'] ||= config['master_branch']
      config['remote'] ||= config['merge_remote'] # For backwards compatibility

      ATTRIBUTES.each do |attr|
        unless config.has_key?(attr.to_s)
          raise RuntimeError.new("git configuration missing. Required config parameters: #{ATTRIBUTES}")
        end

        instance_variable_set("@#{attr}", config[attr.to_s])
      end

      @working_branch = current_branch
    end

    def in_dir
      Dir.chdir(@cmd_runner.dir) do
        yield
      end
    end

    def dir
      @cmd_runner.dir
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

    def run(cmd, opts={})
      @cmd_runner.run("git #{cmd}", opts)
    end

    def add_and_commit(files, message, opts={})
      files = [files].flatten

      index = repo.index
      index.read_tree(repo.head.target.tree)

      files.each do |file|
        oid = Rugged::Blob.from_workdir(repo, file)
        index.add(:path => file, :oid => oid, :mode => 0100644)
      end

      current_tree = index.write_tree(repo)
      options = {}
      options[:tree] = current_tree

      options[:author] = { :email => config_as_hash['user.email'], :name => config_as_hash['user.name'], :time => Time.now }
      options[:committer] = options[:author]
      options[:message] ||= message
      options[:parents] = repo.empty? ? [] : [ repo.head.target ].compact
      options[:update_ref] = 'HEAD'

      Rugged::Commit.create(repo, options)

      index.write
    end

    def branch_contains?(branch, ref)
      run("branch -a --contains #{ref}", log: CmdRunner::LOG_CMD)
      last_stdout.split("\n").detect { |str| str[2..-1] == branch }
    end

    def master_branch_contains?(sha)
      branch_contains?("remotes/#{remote}/#{master_branch}", sha)
    end

    def in_original_merge_branch
      in_branch("#{remote}/#{merge_branch}") { yield }
    end

    def read_file_from_merge_branch(filename)
      run("show #{remote}/#{merge_branch}:#{filename}", log: CmdRunner::LOG_CMD)
      last_stdout
    end

    def initialize_rerere
      return unless use_rerere

      @cmd_runner.run('mkdir .git/rr-cache')
      @cmd_runner.run('cp -R rr-cache/* .git/rr-cache/')
    end

    def commit_rerere(current_rereres)
      return unless use_rerere
      @cmd_runner.run('mkdir rr-cache')
      @cmd_runner.run('rm -rf rr-cache/*')
      current_rereres.each do |rerere|
        @cmd_runner.run("cp -R .git/rr-cache/#{rerere} rr-cache/")
      end

      run('add rr-cache/')
      run("commit -m 'Update rr-cache'")
    end

    def rerere_resolve!
      return false unless use_rerere

      require 'byebug'; debugger
      if unresolved_conflicts.empty?
        # merging_files = staged_and_working_dir_files.select { |s| s.last.empty? }.map(&:first)
        conflicts = conflicted_files

        # run("add #{conflicts.join(" ")}")
        # run('commit --no-edit')

        resolutions(conflicts)
      else
        false
      end
    end

    def unresolved_conflicts
      in_dir do
        conflicted_files.map do |file|
          File.open(file) { |f| f.grep(/>>>>/) }.empty? ? nil : file
        end.compact
      end
    end

    def resolutions(files)
      {}.tap do |hash|
        files.map do |file|
          hash[file] = resolution_candidates(file)
        end.flatten
      end
    end

    # git rerere doesn't give you a deterministic way to determine which resolution was used
    def resolution_candidates(file)
      @cmd_runner.run("diff -q --from-file #{file} .git/rr-cache/*/postimage*", log: CmdRunner::LOG_CMD)
      different_files = split_diff_lines(@cmd_runner.last_stdout)

      @cmd_runner.run('ls -la .git/rr-cache/*/postimage*', log: CmdRunner::LOG_CMD)
      all_files = split_diff_lines(@cmd_runner.last_stdout)

      all_files - different_files
    end

    def split_diff_lines(arr)
      arr.split("\n").map { |s| s.split(".git/rr-cache/").last.split("/postimage").first }
    end

    def staged_and_working_dir_files
      non_new_or_ignored = []

      repo.status do |file, status|
        non_new_or_ignored << [ file, status ] unless status.include?(:ignored) || status.include?(:worktree_new)
      end

      non_new_or_ignored
    end

    def conflicted_files
      staged_and_working_dir_files.select { |s| s.last.empty? }.map(&:first)
      # run("diff --name-only --diff-filter=U")
      # last_stdout.split("\n")
    end

    def current_branch
      repo.head.name.sub(/^refs\/heads\//, '')
    end

    def reset_temp_merge_branch
      repo.checkout(master_branch)
      delete_branch(temp_merge_branch)
      repo.branches.create(temp_merge_branch, repo.branches["#{remote}/#{master_branch}"].target.oid, force: true)
      repo.checkout(temp_merge_branch)
    end

    def delete_branch(branch)
      repo.branches.delete(branch) if repo.branches[branch]
    end

    def push(branch, force=false)
      run("push #{'-f' if force} #{remote} #{branch}")
    end

    def fetch
      run("fetch #{remote}")
    end

    def copy_temp_to_branch(branch, squash_message = nil)
      repo.references.update "refs/heads/#{merge_branch}", repo.branches["refs/remotes/#{remote}/#{merge_branch}"].target.oid

      temp_merge = repo.branches[temp_merge_branch]
      merge = repo.branches[branch]

      temp_merge_commit = temp_merge.target
      merge_commit = merge.target

      index=repo.merge_commits(temp_merge_commit, merge_commit, favor: :ours)
      repo.checkout merge_branch

      options = commit_defaults.merge(
        tree: index.write_tree(repo),
        message: 'merge existing into temp',
        parents: repo.empty? ? [] : [ repo.branches["#{remote}/#{merge_branch}"].target ],
      )
      commit_oid = Rugged::Commit.create(repo, options)

      repo.references.update "refs/heads/#{merge_branch}", commit_oid
      repo.reset(repo.head.target, :hard)

      squash_commits(branch, squash_message) if squash_message
    end

    def delete_temp_merge_branch
      in_branch(master_branch) do
        # run("branch -d #{temp_merge_branch}")
      end
    end

    def in_temp_merge_branch(&block)
      in_branch(temp_merge_branch, &block)
    end

    def in_merge_branch(&block)
      in_branch(merge_branch, &block)
    end

    def in_branch(branch)
      begin
        starting_branch = current_branch
        repo.checkout(branch)

        yield
      ensure
        repo.checkout(starting_branch)
      end
    end

    def temp_merge_branch
      "flash_flow/#{merge_branch}"
    end

    def get_sha(branch, opts={})
      repo.rev_parse(branch).oid
    rescue Rugged::ReferenceError
      nil
    end

    def branch_exists?(branch)
      repo.rev_parse(branch)
      true
    rescue Rugged::ReferenceError
      false
    end

    def ahead_of_master?(branch)
      branch_exists?(branch) && !master_branch_contains?(get_sha(branch))
    end

    private

    def config_as_hash
      Rugged::Config.global.to_hash.merge(repo.config.to_hash)
    end

    def squash_commits(branch, commit_message)
      unless branch_exists?("#{remote}/#{branch}")
        run("push #{remote} #{master_branch}:#{branch}")
      end

      repo.diff("#{remote}/#{branch}", 'origin/test_acceptance').deltas.each do |delta|
        new_file = delta.new_file
        repo.index.add(path: new_file[:path], oid: new_file[:oid], mode: new_file[:mode])
      end

      repo.references.update "refs/heads/#{merge_branch}", repo.branches["#{remote}/#{merge_branch}"].target.oid
      options = commit_defaults.merge(
          tree: repo.index.write_tree(repo),
          message: commit_message,
          parents: repo.empty? ? [] : [ repo.branches["#{remote}/#{merge_branch}"].target ],
      )
      commit_oid = Rugged::Commit.create(repo, options)

      repo.references.update "refs/heads/#{merge_branch}", commit_oid
      repo.reset(repo.head.target, :hard)

      # # Get all the files that differ between existing acceptance and new acceptance
      # files = repo.diff("#{remote}/#{branch}", 'origin/test_acceptance').deltas.map {|d| d.new_file[:path]}
      # run("diff --name-only #{remote}/#{branch} #{branch}")
      # files = last_stdout.split("\n")
      # run("reset #{remote}/#{branch}")
      #
      # run("add -f #{files.map { |f| "\"#{Shellwords.escape(f)}\"" }.join(" ")}")
      #
      # run("commit -m '#{commit_message}'")
    end

    def commit_defaults
      {}.tap do |defaults|
        defaults[:author] = { :email => config_as_hash['user.email'], :name => config_as_hash['user.name'], :time => Time.now }
        defaults[:committer] = defaults[:author]
        defaults[:update_ref] = 'HEAD'
      end
    end
  end
end
