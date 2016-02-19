require 'json'

module FlashFlow
  module Data

    class Branch
      attr_accessor :remote, :remote_url, :ref, :sha, :status, :resolutions, :stories, :conflict_sha, :metadata,
                    :current_record, :merge_order, :updated_at, :created_at

      def initialize(_remote, _remote_url, _ref)
        @remote = _remote
        @remote_url = _remote_url
        @ref = _ref
        @resolutions = {}
        @stories = []
        @merge_order = 0
        @updated_at = Time.now
        @created_at = Time.now
      end

      def self.from_hash(hash)
        branch = new(hash['remote'], hash['remote_url'], hash['ref'])
        branch.sha = hash['sha']
        branch.status = hash['status']
        branch.merge_order = hash['merge_order']
        branch.resolutions = hash['resolutions']
        branch.stories = hash['stories']
        branch.metadata = hash['metadata']
        branch.conflict_sha = hash['conflict_sha'] || hash['metadata'].to_h['conflict_sha']
        branch.updated_at = massage_time(hash['updated_at'])
        branch.created_at = massage_time(hash['created_at'])
        branch
      end

      def self.massage_time(time)
        case time
          when Time
            time
          when NilClass
            Time.now
          else
            Time.parse(time)
        end
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
            'merge_order' => merge_order,
            'resolutions' => resolutions,
            'stories' => stories,
            'conflict_sha' => conflict_sha,
            'metadata' => metadata,
            'updated_at' => updated_at,
            'created_at' => created_at,
        }
      end
      alias :to_h :to_hash

      def to_json(_)
        JSON.pretty_generate(to_hash)
      end

      def merge(other)
        unless other.nil?
          self.sha = other.sha
          self.status = other.status
          self.merge_order = other.merge_order
          self.resolutions = other.resolutions
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

      def set_resolutions(_resolutions)
        self.resolutions = _resolutions
      end

      def success!
        self.status = 'success'
      end

      def success?
        self.status == 'success'
      end

      def fail!(conflict_sha=nil)
        self.conflict_sha = conflict_sha
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

      def deleted!
        self.status = 'deleted'
      end

      def deleted?
        self.status == 'deleted'
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
