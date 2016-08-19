require 'google/api_client/client_secrets'
require 'google/apis/drive_v3'

module FlashFlow
  module Release
    class GoogleDrive

      attr_reader :client

      DRIVE = Google::Apis::DriveV3

      def initialize
        scopes = [DRIVE::AUTH_DRIVE]
        @client = DRIVE::DriveService.new
        @client.authorization = Google::Auth.get_application_default(scopes)
      end

      def upload_file(local_file, config={})
        metadata = DRIVE::File.new(name: File.basename(local_file), extension: 'pdf')
        metadata = @client.create_file(metadata, upload_source: local_file, content_type: 'application/pdf')
        set_file_permissions(metadata.id, config)
      end

      def find_files(query)
        response = @client.list_files(q: query)
        response.files
      end

      def set_file_permissions(file_id, config={})
        @client.batch do
          %w(group user).each do |type|
            %w(reader writer).each do |role| # owner is currently not supported
              config.dig('permissions', type, role).to_s.split(',').each do |email|
                permission = DRIVE::Permission.new(role: role, type: type, email_address: email)
                @client.create_permission(file_id, permission, email_message: config[:email_body], send_notification_email: config['notify'])
              end
            end
          end
        end
      end
    end
  end
end
