require 'nypl_sierra_api_client'

require_relative 'kms_client'

class SierraModel
  @@_sierra_client = nil

  def self.sierra_client
    if @@_sierra_client.nil?
      kms_client = KmsClient.new

      $logger.debug "Creating sierra_client"
      @@_sierra_client = SierraApiClient.new({
        base_url: ENV['SIERRA_API_BASE_URL'],
        oauth_url: ENV['SIERRA_OAUTH_URL'],
        client_id: kms_client.decrypt(ENV['SIERRA_OAUTH_ID']),
        client_secret: kms_client.decrypt(ENV['SIERRA_OAUTH_SECRET'])
      })
    end

    @@_sierra_client
  end
end
