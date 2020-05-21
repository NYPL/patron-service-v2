require_relative 'sierra_model'
require_relative 'errors'

class SierraPatron < SierraModel
  PATRON_FIELDS = 'id,updatedDate,createdDate,deletedDate,deleted,suppressed,names,barcodes,expirationDate,birthDate,emails,patronType,patronCodes,homeLibraryCode,message,blockInfo,addresses,phones,moneyOwed,fixedFields,varFields'

  PATRON_FILTERS_TO_VAR_FIELDS = {
    'email' => 'z',
    'username' => 'u',
    'barcode' => 'b'
  }

  def self.allowed_filters
    PATRON_FILTERS_TO_VAR_FIELDS.keys.concat [ 'id' ]
  end

  def self.by_filters(filters = {})
    # Exclude unsupported filters:
    filters.reject! { |k, v| ! allowed_filters.include? k }

    query = {
      fields: PATRON_FIELDS
    }

    # If no filters, just return first 50 patrons:
    if filters.empty?
      response = self.sierra_client.get 'patrons?' + URI.encode_www_form(query)

      {
        data: response.body['entries'],
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
          data: [ response.body ],
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

  def self.by_id(id)
    query = {
      fields: PATRON_FIELDS
    }

    path = "patrons/#{id}?#{URI.encode_www_form(query)}"

    $logger.debug "Sierra #{path}"

    response = self.sierra_client.get path

    if response.success?
      {
        data: response.body,
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
end
