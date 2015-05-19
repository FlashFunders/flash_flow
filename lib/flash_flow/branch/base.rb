require 'json'

module FlashFlow
  module Branch

    class Base
      attr_accessor :remote, :remote_url, :ref, :sha, :status, :stories, :metadata, :updated_at, :created_at

      def initialize(_remote, _remote_url, _ref)
        @remote = _remote
        @remote_url = _remote_url
        @ref = _ref
        @stories = []
        @updated_at = Time.now
        @created_at = Time.now
      end

      def self.from_hash(hash)
        base = new(hash['remote'], hash['remote_url'], hash['ref'])
        base.sha = hash['sha']
        base.status = hash['status']
        base.stories = hash['stories']
        base.metadata = hash['metadata']
        base.updated_at = hash['updated_at']
        base.created_at = hash['created_at']
        base
      end

      def ==(other)
        other.remote_url == remote_url && other.remote == remote && other.ref == ref
      end

      def to_hash
        {
            'remote' => remote,
            'remote_url' => remote_url,
            'ref' => ref,
            'sha' => sha,
            'status' => status,
            'stories' => stories,
            'metadata' => metadata,
            'updated_at' => updated_at,
            'created_at' => created_at,
        }
      end

      def to_json(_)
        JSON.pretty_generate(to_hash)
      end

      def merge(other)
        unless other.nil?
          self.sha = other.sha
          self.status = other.status
          self.stories = self.stories.to_a | other.stories.to_a
          self.updated_at = Time.now
          self.created_at = [(self.created_at || Time.now), (other.created_at || Time.now)].min
        end

        self
      end

      def add_metadata(data)
        self.metadata ||= {}
        self.metadata.merge!(data)
      end

      def success!
        self.status = 'success'
      end

      def success?
        self.status == 'success'
      end

      def fail!(conflict_sha=nil)
        add_metadata('conflict_sha' => conflict_sha) if conflict_sha
        self.status = 'fail'
      end

      def fail?
        self.status == 'fail'
      end

      def removed!
        self.status = 'removed'
      end

      def removed?
        self.status == 'removed'
      end

      def unknown!
        self.status = nil
      end

      def unknown?
        self.status.nil?
      end
    end

  end
end
