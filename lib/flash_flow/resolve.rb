require 'logger'

require 'flash_flow/git'
require 'flash_flow/data'

module FlashFlow
  class Resolve

    class NothingToResolve < StandardError; end

    def initialize(git_config, branch_info_file, opts={})
      @logger = opts[:logger]
      @branch_info_file = branch_info_file
      @cmd_runner = CmdRunner.new(logger: @logger)
      @git = Git.new(git_config, @logger)
    end

    def manual_instructions
      branch = check_for_conflict
      puts manual_not_merged_instructions(branch)
    end

    def start
      check_for_conflict

      in_shadow_repo do
        in_working_branch do
          merge_conflicted

          if unresolved_conflicts.empty?
            puts "You have already resolved all conflicts."
          else
            launch_bash

            rerere

            unless unresolved_conflicts.empty?
              puts "There are still unresolved conflicts in these files:\n#{unresolved_conflicts.join("\n")}\n\n"
            end
          end

          git_reset
        end
      end
    end

    def unresolved_conflicts
      @git.unresolved_conflicts
    end

    def merge_conflicted
      @git.run("checkout #{branch.conflict_sha}")
      @git.run("merge origin/#{working_branch}")
    end

    def git_reset
      @git.run("reset --hard HEAD")
    end

    def rerere
      @git.run("rerere")
    end

    def bash_message
      puts "\nPlease fix the following conflicts and then 'exit':\n#{unresolved_conflicts.join("\n")}\n\n"
    end

    def launch_bash
      bash_message

      with_init_file do |file|
        system("bash --init-file #{file} -i")
      end
    end

    def with_init_file
      filename = '.flash_flow_init'
      File.open(filename, 'w') do |f|
        f.puts(init_file_contents)
      end

      yield filename

      File.delete(filename)
    end

    def manual_not_merged_instructions(branch)
      <<-EOS

Run the following commands to fix the merge conflict and then re-run flash_flow:
  pushd #{flash_flow_directory}
  git checkout #{branch.conflict_sha}
  git merge #{working_branch}
  # Resolve the conflicts
  git add <conflicted files>
  git commit --no-edit
  popd

      EOS
    end

    private

    def data
      return @data if @data

      in_shadow_repo do
        @data = Data::Base.new({}, @branch_info_file, @git, logger: @logger)
      end

      @data

    end

    def branch
      @branch ||= data.saved_branches.detect { |branch| branch.ref == working_branch }
    end

    def shadow_repo
      @shadow_repo ||= ShadowRepo.new(@git, logger: @logger)
    end

    def in_shadow_repo
      shadow_repo.in_dir do
        yield
      end
    end

    def working_branch
      @git.working_branch
    end

    def in_working_branch
      @git.in_branch(working_branch) do
        yield
      end
    end

    def flash_flow_directory
      shadow_repo.flash_flow_dir
    end

    def init_file_contents
      <<-EOS
        # Commented this one out because it was causing lots of spurious "saving session..." type messages
        # [[ -s /etc/profile ]] && source /etc/profile
        [[ -s ~/.bash_profile ]] && source ~/.bash_profile
        [[ -s ~/.bash_login ]] && source ~/.bash_login
        [[ -s ~/.profile ]] && source ~/.profile
        [[ -s ~/.bashrc ]] && source ~/.bashrc

        PS1='flash_flow resolve: (type "exit" after your conflicts are resolved)$ '
      EOS
    end

    def check_for_conflict
      raise NothingToResolve.new("The current branch (#{working_branch}) does not appear to be in conflict.") unless branch.conflict_sha
    end
  end
end
