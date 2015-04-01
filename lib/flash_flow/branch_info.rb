module FlashFlow
  class BranchInfo

    def self.write(filename, successes, failures)
      File.open(filename, 'w') do |f|
        f.puts '<html><body>'

        if successes.empty?
          f.puts "<h1>No merged branches</h1>"
        else
          f.puts "<h1>Merged branches</h1>"
          print_list(f, successes)
        end

        if failures.empty?
          f.puts "<h1>No merge failures</h1>"
        else
          f.puts "<h1>Pull requested branches that didn't merge</h1>"
          print_list(f, failures)
        end

        f.puts '</body></html>'
      end
    end

    def self.print_list(f, list)
      f.puts '<ul>'
      list.each do |remote, ref|
        f.puts "<li>#{remote}/#{ref}</li>"
      end
      f.puts '</ul>'
    end
  end
end
