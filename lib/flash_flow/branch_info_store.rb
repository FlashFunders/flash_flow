require 'json'

module FlashFlow
  class BranchInfoStore
    def initialize(filename, opts={})
      @filename = filename
      @logger = opts[:logger] || Logger.new('/dev/null')
    end

    def get(file=File.open(@filename, 'r'))
      JSON.parse(file.read)
    rescue JSON::ParserError
      @logger.info "Unable to read branch info from file: #{@filename}"
      {}
    end

    def write(branches, file=File.open(@filename, 'w'))
      file.puts branches.to_json
      file.close
    end

  end
end
