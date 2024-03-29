require 'date'

require_relative 'sierra_model'
require_relative 'errors'

class SierraPatron < SierraModel
  PATRON_FIELDS = 'id,updatedDate,createdDate,deletedDate,deleted,suppressed,names,barcodes,expirationDate,birthDate,emails,patronType,patronCodes,homeLibraryCode,message,blockInfo,addresses,phones,moneyOwed,fixedFields,varFields'
  DEFAULT_FIELDS = ENV['DEFAULT_FIELDS'] || 'id,names,barcodes,expirationDate,emails,patronType,homeLibraryCode,phones,moneyOwed,fixedFields'

  PATRON_FILTERS_TO_VAR_FIELDS = {
    'email' => 'z',
    'username' => 'u',
    'barcode' => 'b'
  }

  def self.allowed_filters
    PATRON_FILTERS_TO_VAR_FIELDS.keys.concat [ 'id' ]
  end

  def self.fields(requested_fields)
    requested_fields ||= DEFAULT_FIELDS
    requested_fields == 'all' ? PATRON_FIELDS : requested_fields
  end

  def self.by_filters(filters = {}, requested_fields = nil)
    # Exclude unsupported filters:
    filters.reject! { |k, v| ! allowed_filters.include? k }

    query = {
      fields: self.fields(requested_fields)
    }

    # If no filters, just return first 50 patrons:
    if filters.empty?

      path = "patrons?#{URI.encode_www_form(query)}"
      $logger.debug "Performing Sierra query: #{path}"
      response = self.sierra_client.get path

      {
        data: response.body['entries'].map { |patron| self.format_patron_record patron },
        count: response.body['total'],
        statusCode: response.code
      }

    else
      # Only actually use the last filter (to match legacy PatronService):
      filter_name = filters.keys.last
      if filter_name == 'id'
        query['id'] = filters['id']
      else
        query['varFieldTag'] = PATRON_FILTERS_TO_VAR_FIELDS[filter_name]
        query['varFieldContent'] = filters[filter_name]
      end

      path = 'patrons/find?' + URI.encode_www_form(query)

      $logger.debug "Performing Sierra query: #{path}"

      response = self.sierra_client.get path

      if response.success?
        {
          data: [ self.format_patron_record(response.body) ],
          count: 1,
          statusCode: response.code
        }
      else
        {
          message: "Failed to retrieve patron record by #{filter_name}=#{filters[filter_name]}",
          statusCode: response.code
        }
      end
    end
  end

  def self.by_id(id, requested_fields = nil)
    query = {
      fields: self.fields(requested_fields)
    }

    path = "patrons/#{id}?#{URI.encode_www_form(query)}"

    $logger.debug "Sierra #{path}"

    response = self.sierra_client.get path

    if response.success?
      {
        data: self.format_patron_record(response.body),
        count: 1,
        statusCode: response.code
      }
    else
      {
        message: "Failed to retrieve #{path} from Sierra",
        statusCode: response.code
      }
    end
  end

  def self.validate(barcode, pin)
    raise ParameterError, 'barcode and pin required' unless barcode && pin
    raise ParameterError, 'barcode required' unless barcode
    raise ParameterError, 'pin required' unless pin

    path = 'patrons/validate'

    $logger.debug "Performing Sierra query: #{path} { 'barcode': '#{barcode}', 'pin': '#{pin.to_s.gsub(/./, '*')}' }"

    response = self.sierra_client.post path, { 'barcode' => barcode, 'pin' => pin }

    raise ParameterError, 'Invalid patron barcode and/or pin' if response.error?

    {
      statusCode: response.code,
      valid: true,
      message: "Successfully validated patron with barcode #{barcode}"
    }
  end


  def self.format_patron_record(patron)
    # If Sierra didn't return valid JSON, don't attempt transformations:
    return patron unless patron.is_a?(Hash)

    # Create "barCodes" alias for barcodes, per legacy PatronService:
    result = { 'barCodes' => patron['barcodes'] }.merge patron

    # Translate the following fixed fields into integers:
    # (This was the practice of the legacy PatronService, presumably to suit HTC's needs.)
    [
      '96', # Money owed
      '123' # Debit Balance
    ].each do |fixed_num|
      result['fixedFields'][fixed_num]['value'] = result['fixedFields'][fixed_num]['value'].to_i unless result.dig('fixedFields', fixed_num, 'value').nil?
    end

    # Ensure datetimes are formatted correctly:
    [
      'createdDate',
      'updatedDate'
    ].each do |date_property|
      # Sierra datetimes resemble:  "2020-04-21T01:00:37Z"
      # We want them formatted as:  "2020-04-21T01:00:37+00:00"
      result[date_property] = DateTime.parse(result[date_property]).strftime('%FT%T%:z') unless result[date_property].nil?
    end

    result
  end
end
