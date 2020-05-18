require 'uri'
require 'json'
require 'nypl_log_formatter'

require_relative 'lib/sierra_patron'

def init
  return if $initialized

  $logger = NyplLogFormatter.new(STDOUT, level: ENV['LOG_LEVEL'] || 'info')

  $swagger_doc = JSON.load(File.read('./swagger.json'))

  $initialized = true
end

def handle_event(event:, context:)
  init

  path = event["path"]
  method = event["httpMethod"].downcase

  $logger.debug "Handling #{method} #{path}"

  begin
    response = nil
    if method == 'get' && path == "/docs/patron"
      return respond 200, $swagger_doc
    elsif method == 'get' && path == '/api/v0.1/patrons'
      response = handle_patrons event
    elsif method == 'get' && /\/api\/v0.1\/patrons(\/(\d+))?/.match?(path)
      response = handle_patron event
    elsif method == 'post' && path == '/api/v0.1/patrons/validate'
      response = handle_patron_validate event
    else
      return respond 400, 'Bad method'
    end
    respond response['statusCode'], response

  rescue ParameterError => e
    respond 400, message: "ParameterError: #{e.message}"
  rescue NotFoundError => e
    respond 404, message: "NotFoundError: #{e.message}"
  rescue => e
    $logger.error("Error #{e.backtrace}")

    respond 500, message: e.message
  end
end

def handle_patron(event)
  id = event.dig 'pathParameters', 'id'

  $logger.debug "SierraPatron.by_id #{id}"

  SierraPatron.by_id id
end

def handle_patrons(event)
  # Build hash of used filters:
  filters = parse_params SierraPatron.allowed_filters, event

  SierraPatron.by_filters filters
end

def handle_patron_validate(event)
  params = parse_body event

  SierraPatron.validate params['barcode'], params['pin']
end

def handle_swagger
  {
    statusCode: statusCode,
    headers: {
      "Content-type": "application/json"
    }
  }
end

# Parse array of named params from given ApiGateway event
def parse_params(params, event)
  # If no query string, return empty hash
  return {} unless event.is_a?(Hash) && event['queryStringParameters']

  params.inject({}) do |h, param|
    filter_val = event.dig 'queryStringParameters', param
    h[param] = filter_val unless filter_val.nil?
    h
  end
end

def parse_body(event)
  # If no body, return empty hash
  return {} unless event.is_a?(Hash) && event['body']

  params = event['body']
  params = Base64.decode64 params if event['isBase64Encoded']
  JSON.parse params
end

def respond(statusCode = 200, body = nil)
  $logger.debug("Responding with #{statusCode}", body)

  {
    statusCode: statusCode,
    body: body.to_json,
    headers: {
      "Content-type": "application/json"
    }
  }
end
