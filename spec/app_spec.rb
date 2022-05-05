require 'spec_helper'

require_relative '../app'

describe :app, :type => :controller do
  before do
    $logger = NyplLogFormatter.new(STDOUT, level: ENV['LOG_LEVEL'] || 'info')
  end

  describe :parse_params do
    it 'parses empty query params' do
      expect(parse_params(['foo'], nil)).to eq({})
      expect(parse_params(['foo'], {})).to eq({})
      expect(parse_params(['foo'], { "queryStringParameters" => nil })).to eq({})
      expect(parse_params(['foo'], { "queryStringParameters" => {}})).to eq({})
    end

    it 'parses named query param' do
      expect(parse_params(['key1'], { "queryStringParameters" => {}})).to be_empty
      expect(parse_params(['key1'], { "queryStringParameters" => { "key2" => "foo" }})).to be_empty
      expect(parse_params(['key1'], { "queryStringParameters" => { "key1" => "foo" }})).to include({ 'key1' => 'foo' })
      expect(parse_params(['key1'], { "queryStringParameters" => { "key2" => "value2", "key1" => "value1" }})).to include({ 'key1' => 'value1' })
    end
  end

  describe :parse_body do
    it 'parses empty body' do
      expect(parse_body(nil)).to eq({})
      expect(parse_body({})).to eq({})
    end

    it 'parses plain json body' do
      expect(parse_body({ 'body' => '{ "key1": "value2" }' })).to include({ "key1" => "value2" })
    end

    it 'parses base64 encoded json body' do
      expect(parse_body({ 'body' => '{ "key1": "value2" }', 'bodyIsBase64Encoded' => true })).to include({ "key1" => "value2" })
    end
  end

  describe :handle_event do
    before(:each) do
      KmsClient.aws_kms_client.stub_responses(:decrypt, -> (context) {
        # "Decrypt" by subbing "encrypted" with "decrypted" in string:
        { plaintext: context.params[:ciphertext_blob].gsub('encrypted', 'decrypted') }
      })

      stub_request(:post, "#{ENV['SIERRA_OAUTH_URL']}").to_return(status: 200, body: '{ "access_token": "fake-access-token" }')

    end

    it 'responds to /docs/patron with 200 and swagger doc' do
      response = handle_event(
        event: {
          "path" => '/docs/patron',
          "httpMethod" => 'GET'
        },
        context: {}
      )

      expect(response[:statusCode]).to eq(200)
      expect(response[:body]).to be_a(String)
      expect(JSON.parse(response[:body])).to be_a(Hash)
      expect(JSON.parse(response[:body])['paths']).to be_a(Hash)
    end

    it 'responds to patrons/12345 with 200 and patron body' do
      stub_request(:get, "#{ENV['SIERRA_API_BASE_URL']}patrons/12345")
        .with(query: { "fields" => SierraPatron::PATRON_FIELDS })
        .to_return({
          status: 200,
          body: File.read('./spec/fixtures/patron-12345.json'),
          headers: { 'Content-Type' => 'application/json;charset=UTF-8' }
        })

      response = handle_event(
        event: {
          "path" => '/api/v0.1/patrons/12345',
          "httpMethod" => 'GET',
          "pathParameters" => { "id" => '12345' }
        },
        context: {}
      )

      expect(response[:statusCode]).to eq(200)
      expect(response[:body]).to be_a(String)
      expect(JSON.parse(response[:body])).to be_a(Hash)
      expect(JSON.parse(response[:body])['data']).to be_a(Hash)
      expect(JSON.parse(response[:body])['data']['id']).to eq(12345)
    end

    it 'passes Sierra status code to response' do
      stub_request(:get, "#{ENV['SIERRA_API_BASE_URL']}patrons/5678")
        .with(query: { "fields" => SierraPatron::PATRON_FIELDS })
        .to_return({
          status: 418,
          body: {
            "code" => 107,
            "specificCode" => 0,
            "httpStatus" => 418,
            "name" => "I am a teapot"
          }.to_json,
          headers: { 'Content-Type' => 'application/json;charset=UTF-8' }
        })

      response = handle_event(
        event: {
          "path" => '/api/v0.1/patrons/5678',
          "httpMethod" => 'GET',
          "pathParameters" => { "id" => '5678' }
        },
        context: {}
      )

      expect(response[:statusCode]).to eq(418)
      expect(response[:body]).to be_a(String)

      # Expect CORS and Content-Type headers:
      expect(response[:headers]).to be_a(Hash)
      expect(response[:headers]).to include(
        :'Access-Control-Allow-Origin' => '*',
        :'Content-Type' => 'application/json'
      )

      expect(JSON.parse(response[:body])).to be_a(Hash)
      expect(JSON.parse(response[:body])['message']).to start_with("Failed to retrieve")
    end
  end
end
