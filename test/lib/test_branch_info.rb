require 'minitest_helper'

module FlashFlow
  class TestBranchInfo < Minitest::Test
    def no_failures_output
      <<-EOS
      <html>
        <body>
          <h1>Merged branches</h1>
          <ul>
            <li>origin/branch 1</li>
            <li>other_origin/branch 2</li>
          </ul>
          <h1>No merge failures</h1>
        </body>
      </html>
      EOS
    end

    def no_successes_output
      <<-EOS
      <html>
        <body>
          <h1>No merged branches</h1>
          <h1>Pull requested branches that didn't merge</h1>
          <ul>
            <li>origin/fail 1</li>
            <li>other_origin/fail 2</li>
          </ul>
        </body>
      </html>
      EOS
    end

    def test_write_no_failures
      io = StringIO.new

      File.stub(:open, true, io) do
        BranchInfo.write('fake_name', [['origin', 'branch 1'], ['other_origin', 'branch 2']], [])
      end

      assert_equal(no_failures_output.gsub(/\s/, ''), io.string.gsub(/\s/, ''))
    end

    def test_write_no_successes
      io = StringIO.new

      File.stub(:open, true, io) do
        BranchInfo.write('fake_name', [], [['origin', 'fail 1'], ['other_origin', 'fail 2']])
      end

      assert_equal(no_successes_output.gsub(/\s/, ''), io.string.gsub(/\s/, ''))
    end

  end
end
