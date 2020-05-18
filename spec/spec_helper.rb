require 'spec_helper'
require 'nypl_log_formatter'
require 'webmock/rspec'
require 'aws-sdk-kms'

require_relative '../lib/errors'

ENV['LOG_LEVEL'] ||= 'info'
ENV['SIERRA_API_BASE_URL'] = 'https://example.com/iii/'
ENV['SIERRA_OAUTH_ID'] = Base64.strict_encode64 'fake-client'
ENV['SIERRA_OAUTH_SECRET'] = Base64.strict_encode64 'fake-secret'
ENV['SIERRA_OAUTH_URL'] = 'https://example.com/oauth'
ENV['APP_ENV'] = 'test'

$logger = NyplLogFormatter.new(STDOUT, level: ENV['LOG_LEVEL'] || 'info')

Aws.config[:kms] = {
  stub_responses: {
    decrypt: {
      plaintext: 'decrypted'
    }
  }
}
