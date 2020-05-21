require 'spec_helper'

describe SierraPatron do
  before(:each) do
    KmsClient.aws_kms_client.stub_responses(:decrypt, -> (context) {
      # "Decrypt" by subbing "encrypted" with "decrypted" in string:
      { plaintext: context.params[:ciphertext_blob].gsub('encrypted', 'decrypted') }
    })

    stub_request(:post, "#{ENV['SIERRA_OAUTH_URL']}").to_return(status: 200, body: '{ "access_token": "fake-access-token" }')
  end

  describe :by_id do
    it "calls Sierra patron/:id endpoint, returns record" do
      stub_request(:get, "#{ENV['SIERRA_API_BASE_URL']}patrons/12345")
        .with(query: { "fields" => SierraPatron::PATRON_FIELDS })
        .to_return({
          status: 200,
          body: File.read('./spec/fixtures/patron-12345.json'),
          headers: { 'Content-Type' => 'application/json;charset=UTF-8' }
        })

      resp = SierraPatron.by_id 12345

      expect(resp[:statusCode]).to eq(200)
      expect(resp[:data]).to be_a(Hash)
      expect(resp[:data]['id']).to eq(12345)
    end

    it "handles deleted patron records" do
      stub_request(:get, "#{ENV['SIERRA_API_BASE_URL']}patrons/56789")
        .with(query: { "fields" => SierraPatron::PATRON_FIELDS })
        .to_return({
          status: 200,
          body: File.read('./spec/fixtures/patron-56789-deleted.json'),
          headers: { 'Content-Type' => 'application/json;charset=UTF-8' }
        })

      resp = SierraPatron.by_id 56789

      expect(resp[:statusCode]).to eq(200)
      expect(resp[:data]).to be_a(Hash)
      expect(resp[:data]['id']).to eq(56789)
      expect(resp[:data]['deleted']).to eq(true)
    end

    it "handles missing patron records" do
      stub_request(:get, "#{ENV['SIERRA_API_BASE_URL']}patrons/56789")
        .with(query: { "fields" => SierraPatron::PATRON_FIELDS })
        .to_return({
          status: 404,
          body: File.read('./spec/fixtures/patron-56789-missing.json'),
          headers: { 'Content-Type' => 'application/json;charset=UTF-8' }
        })

      resp = SierraPatron.by_id 56789

      expect(resp[:statusCode]).to eq(404)
      expect(resp[:data]).to be_nil
      expect(resp[:message]).to start_with("Failed to retrieve")
    end

    it "passes through malformed responses from Sierra" do
      stub_request(:get, "#{ENV['SIERRA_API_BASE_URL']}patrons/56789")
        .with(query: { "fields" => SierraPatron::PATRON_FIELDS })
        .to_return(status: 200, body: "<html><body>Unexpected Error</body></html")

      resp = SierraPatron.by_id 56789

      expect(resp[:statusCode]).to eq(200)
      expect(resp[:data]).to be_a(String)
      expect(resp[:data]).to eq("<html><body>Unexpected Error</body></html")
    end
  end

  describe :by_filters do
    it "calls Sierra patrons endpoint, returns first 50 records" do
      stub_request(:get, "#{ENV['SIERRA_API_BASE_URL']}patrons")
        .with(query: { "fields" => SierraPatron::PATRON_FIELDS })
        .to_return({
          status: 200,
          body: File.read('./spec/fixtures/patrons.json'),
          headers: { 'Content-Type' => 'application/json;charset=UTF-8' }
        })

      resp = SierraPatron.by_filters

      expect(resp[:statusCode]).to eq(200)
      expect(resp[:count]).to eq(50)
      expect(resp[:data]).to be_a(Array)
      expect(resp[:data][0]).to be_a(Hash)
      expect(resp[:data][0]['id']).to eq(1000001)
    end

    it "calls Sierra patrons/find endpoint, returns array of records" do
      stub_request(:get, "#{ENV['SIERRA_API_BASE_URL']}patrons/find")
        .with(query: {
          "fields" => SierraPatron::PATRON_FIELDS,
          "varFieldContent" => "user@example.com",
          "varFieldTag" => "z"
         })
        .to_return({
          status: 200,
          body: File.read('./spec/fixtures/patron-12345.json'),
          headers: { 'Content-Type' => 'application/json;charset=UTF-8' }
        })

      resp = SierraPatron.by_filters({ 'email' => 'user@example.com' })

      expect(resp[:statusCode]).to eq(200)
      expect(resp[:count]).to eq(1)
      expect(resp[:data]).to be_a(Array)
      expect(resp[:data][0]).to be_a(Hash)
      expect(resp[:data][0]['id']).to eq(12345)
    end

    it "calls Sierra patrons/find endpoint, returns error response when Sierra responds with 404" do
      stub_request(:get, "#{ENV['SIERRA_API_BASE_URL']}patrons/find")
        .with(query: {
          "fields" => SierraPatron::PATRON_FIELDS,
          "varFieldContent" => "user@example.com",
          "varFieldTag" => "z"
         })
        .to_return({
          status: 404,
          body: File.read('./spec/fixtures/patron-56789-missing.json'),
          headers: { 'Content-Type' => 'application/json;charset=UTF-8' }
        })

      resp = SierraPatron.by_filters({ 'email' => 'user@example.com' })

      expect(resp[:statusCode]).to eq(404)
      expect(resp[:count]).to be_nil
      expect(resp[:data]).to be_nil
      expect(resp[:message]).to eq('Failed to retrieve patron record by email=user@example.com')
    end

    it "calls Sierra patrons/find endpoint when querying by id" do
      stub_request(:get, "#{ENV['SIERRA_API_BASE_URL']}patrons/find")
        .with(query: {
          "fields" => SierraPatron::PATRON_FIELDS,
          "id" => "12345"
         })
        .to_return({
          status: 200,
          body: File.read('./spec/fixtures/patron-12345.json'),
          headers: { 'Content-Type' => 'application/json;charset=UTF-8' }
        })

      resp = SierraPatron.by_filters({ 'id' => '12345' })

      expect(resp[:statusCode]).to eq(200)
      expect(resp[:count]).to eq(1)
      expect(resp[:data]).to be_a(Array)
      expect(resp[:data][0]).to be_a(Hash)
      expect(resp[:data][0]['id']).to eq(12345)
    end

    it "ignores unsupported filters, returning first 50 instead", current: true  do
      stub_request(:get, "#{ENV['SIERRA_API_BASE_URL']}patrons")
        .with(query: { "fields" => SierraPatron::PATRON_FIELDS })
        .to_return({
          status: 200,
          body: File.read('./spec/fixtures/patrons.json'),
          headers: { 'Content-Type' => 'application/json;charset=UTF-8' }
        })

      resp = SierraPatron.by_filters({ 'emailsss' => 'user@example.com' })

      expect(resp[:statusCode]).to eq(200)
      expect(resp[:count]).to eq(50)
      expect(resp[:data]).to be_a(Array)
      expect(resp[:data][0]).to be_a(Hash)
      expect(resp[:data][0]['id']).to eq(1000001)
    end
  end

  describe :validate do
    it "raises error if params missing" do
      expect { SierraPatron.validate(nil, nil) }.to raise_error(ParameterError)
      expect { SierraPatron.validate(123456678, nil) }.to raise_error(ParameterError)
      expect { SierraPatron.validate(nil, 1234) }.to raise_error(ParameterError)
    end

    it "passes barcode and pin to validate valid credentials", current: true  do
      stub_request(:post, "#{ENV['SIERRA_API_BASE_URL']}patrons/validate")
        .with(body: { "barcode" => 123456789, "pin": 1234 })
        .to_return({
          status: 204,
          body: '',
          headers: { 'Content-Type' => 'application/json;charset=UTF-8' }
        })

      resp = SierraPatron.validate(123456789, 1234)

      expect(resp[:statusCode]).to eq(204)
      expect(resp[:valid]).to eq(true)
      expect(resp[:message]).to eq("Successfully validated patron with barcode #{123456789}")
    end

    it "handles invalid credentials as a 400", current: true  do
      stub_request(:post, "#{ENV['SIERRA_API_BASE_URL']}patrons/validate")
        .with(body: { "barcode" => 123456789, "pin": 1234 })
        .to_return({
          status: 400,
          body: File.read('./spec/fixtures/patron-validate-invalid.json'),
          headers: { 'Content-Type' => 'application/json;charset=UTF-8' }
        })

      expect { SierraPatron.validate(123456789, 1234) }.to raise_error(ParameterError)

      expect(WebMock).to have_requested(:post, "#{ENV['SIERRA_API_BASE_URL']}patrons/validate")
        .with(body: { "barcode" => 123456789, "pin": 1234 })
    end
  end
end
