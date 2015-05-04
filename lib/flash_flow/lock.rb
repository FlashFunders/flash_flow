module FlashFlow
  class Lock
    class Error < RuntimeError; end

    def with_lock(issue_id, &block)
      yield
    end
  end
end
