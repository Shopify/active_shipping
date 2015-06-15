module ActiveShipping

  class USPSReturns < Carrier

    self.retry_safe = true

    cattr_reader :name
    @@name = "USPS Returns"

    LIVE_DOMAIN = 'returns.usps.com'
    LIVE_RESOURCE = 'Services/ExternalCreateReturnLabel.svc/ExternalCreateReturnLabel'

    TEST_DOMAIN = 'returns.usps.com'
    TEST_RESOURCE = 'Services/ExternalCreateReturnLabel.svc/ExternalCreateReturnLabel'

    API_CODES = {
      :external_return_label_request => 'externalReturnLabelRequest'
    }

    USE_SSL = {
      :external_return_label_request => true
    }

    def requirements
      []
    end

    def external_return_label_request(label, options = {})
      response = commit(:external_return_label_request, label.to_xml, (options[:test] || false))
      parse_external_return_label_response(response)
    end

    protected

    def parse_external_return_label_response(response)
      tracking_number, postal_routing, return_label, message = '', '', '', '', ''
      xml = Nokogiri::XML(response)
      error = external_return_label_errors(xml)
      if error.is_a?(Hash) && error.size > 0
        message << "#{error[:error][:code]}: #{error[:error][:message]}"
      else
        tracking_number = xml.at('TrackingNumber').try(:text)
        postal_routing = xml.at('PostalRouting').try(:text)
        return_label = xml.at('ReturnLabel').try(:text)
      end

      ExternalReturnLabelResponse.new(message.length == 0, message, Hash.from_xml(response),
        :xml => response,
        :carrier => @@name,
        :request => last_request,
        :return_label => return_label,
        :postal_routing => postal_routing,
        :tracking_number => tracking_number
      )
    end

    def external_return_label_errors(document)
      return {} unless document.respond_to?(:elements)
      res = {}
      if node = document.at('*/errors')
        if node.at('ExternalReturnLabelError')
          if message = node.at('ExternalReturnLabelError/InternalErrorDescription').try(:text)
            code = node.at('ExternalReturnLabelError/InternalErrorNumber').try(:text) || ''
            res = {:error => {:code => code, :message => message}}
          elsif message = node.at('ExternalReturnLabelError/ExternalErrorDescription').try(:text)
            code = node.at('ExternalReturnLabelError/ExternalErrorNumber').try(:text) || ''
            res = {:error => {:code => code, :message => message}}
          end
        end
      end
      res
    end

    def commit(action, request, test = false)
      ssl_get(request_url(action, request, test))
    end

    def request_url(action, request, test)
      scheme = USE_SSL[action] ? 'https://' : 'http://'
      host = test ? TEST_DOMAIN : LIVE_DOMAIN
      resource = test ? TEST_RESOURCE : LIVE_RESOURCE
      "#{scheme}#{host}/#{resource}?#{API_CODES[action]}=#{URI.encode(request)}"
    end

  end
end
