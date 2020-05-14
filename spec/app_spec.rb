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
end
