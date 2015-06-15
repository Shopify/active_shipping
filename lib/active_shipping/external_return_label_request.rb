# -*- coding: utf-8 -*-
module ActiveShipping

  class ExternalReturnLabelRequest

    CAP_STRING_LEN = 100

    USPS_EMAIL_REGEX = /^([a-zA-Z0-9_\-\.]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([a-zA-Z0-9\-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?)$/

    LABEL_FORMAT = {
      'Instructions' => 'null',
      'No Instructions' => 'NOI',
      'Double Label' => 'TWO'
    }

    SERVICE_TYPE_CODE = [
      '044', '019', '596', '020', '597','022', '024', '017', '018'
    ]

    CALL_CENTER_OR_SELF_SERVICE = ['CallCenter', 'Customer']

    LABEL_DEFINITION = ['4X6', 'Zebra-4X6', '4X4', '3X6']

    IMAGE_TYPE = ['PDF', 'TIF']

    attr_reader :customer_name,
                :customer_address1,
                :customer_address2,
                :customer_city,
                :customer_state,
                :customer_zipcode,
                :customer_urbanization,
                :company_name,
                :attention,
                :label_format,
                :label_definition,
                :service_type_code,
                :merchandise_description,
                :insurance_amount,
                :address_override_notification,
                :packaging_information,
                :packaging_information2,
                :call_center_or_self_service,
                :image_type,
                :address_validation,
                :sender_name,
                :sender_email,
                :recipient_name,
                :recipient_email,
                :recipient_bcc,
                :merchant_account_id,
                :mid

    def initialize(options = {})
      options.each do |pair|
        self.public_send("#{pair[0]}=".to_sym, pair[1]) if self.respond_to?("#{pair[0]}=".to_sym)
      end

      verify_or_raise_required
    end

    def self.from_hash(options={})
      self.new(options)
    end

    # Sent by the system containing the returns label attachment and message.
    def recipient_bcc=(v)
      @recipient_bcc = validate_email(v, __method__)
    end

    # Sent by the system containing the returns label attachment and message.
    # <em>Optional</em>.
    def recipient_email=(v)
      @recipient_email = validate_email(v, __method__)
    end

    # The name in an email sent by the system containing the returns label attachment.
    # <em>Optional</em>.
    def recipient_name=(v)
      @recipient_name = nil
      if (v = sanitize(v)) && v.length > 0
        @recipient_name = v
      else
        raise USPSValidationError, "'#{v}' is not a valid string in #{__method__}"
      end
    end

    # The From address in an email sent by the system containing the returns
    # label attachment and message, Defaults to DONOTREPLY@USPSReturns.com
    # if a recipient email is entered and a sender email is not.
    # <em>Optional</em>.
    def sender_email=(v)
      @sender_email = validate_email(v, __method__)
    end

    # The From name in an email sent by the system containing the returns
    # label attachment.  Defaults to “Merchant Returns” if a recipient name
    # is entered and a sender name is not.
    # <em>Optional</em>.
    def sender_name=(v)
      @sender_name = nil
      if (v = sanitize(v)) && v.length > 0
        @sender_name = v
      else
        raise USPSValidationError, "'#{v}' is not a valid string in #{__method__}"
      end
    end

    # Used to override the validation of the customer address.
    # If true, the address will be validated against WebTools.
    # If false, the system will bypass the validation.
    # <em>Optional</em>.
    def address_validation=(v)
      @address_validation = to_bool(v, true)
    end

    # Used to select the format of the return label.
    # <em>Optional</em>.
    # * PDF <em>Default</em>.
    # * TIF
    def image_type=(v)
      @image_type = validate_set_inclusion(v.to_s.upcase, IMAGE_TYPE, __method__)
    end

    # Used to determine if the returns label request is coming from a
    # merchant call center agent or an end customer.
    # <b>Required</b>.
    # [CallCenter]
    # [Customer]
    def call_center_or_self_service=(v)
      @call_center_or_self_service = validate_set_inclusion(v, CALL_CENTER_OR_SELF_SERVICE, __method__)
    end

    # Package information can be one of three types: RMA, Invoice or
    # Order number. This will appear on the second label generated when
    # the LabelFormat “TWO” is selected.
    # <em>Optional</em>.
    def packaging_information2=(v)
      @packaging_information2 = validate_string_length(v, 15, __method__)
    end

    # Package information can be one of three types: RMA, Invoice or
    # Order number. This will appear on the generated label.
    # <em>Optional</em>.
    def packaging_information=(v)
      @packaging_information = validate_string_length(v, 15, __method__)
    end

    # Override address if more address information
    # is needed or system cannot find address. If
    # the address_override_notification value is
    # true then any address error being passed from
    # WebTools would be bypassed and a successful
    # response will be sent.
    # <b>Required</b>.
    def address_override_notification=(v)
      @address_validation = to_bool(v)
    end

    # Insured amount of package.
    def insurance_amount=(v)
      @insurance_amount = nil
      if (1..200).include?(v.to_f)
        @insurance_amount = v
      else
        raise USPSValidationError, "#{__method__} must be a numerical value between 1 and 200, found value '#{v}'."
      end
    end

    # Description of the merchandise.
    # <em>Optional</em>.
    def merchandise_description=(v)
      @merchandise_description = validate_string_length(v, 255, __method__)
    end

    # Service type of the label as specified in the merchant profile setup.
    # <b>Required</b>.
    # [044] (Parcel Return Service)
    # [019] (Priority Mail Returns service)
    # [596] (Priority Mail Returns service, Insurance <= $200)
    # [020] (First-Class Package Return service)
    # [597] (First-Class Package Return service, Insurance <= $200)
    # [022] (Ground Return Service)
    # [024] (PRS – Full Network)
    # [017] (PRS – Full Network, Insurance <=$200)
    # [018] (PRS – Full Network, Insurance >$200)
    def service_type_code=(v)
      @service_type_code = validate_set_inclusion(v, SERVICE_TYPE_CODE, __method__)
    end

    # Size of the label.
    # <b>Required</b>.
    # * 4X6
    # * Zebra-4X6
    # * 4X4
    # * 3X6
    def label_definition=(v)
      @label_definition = validate_set_inclusion(v, LABEL_DEFINITION, __method__)
    end

    def label_format
      @label_format && LABEL_FORMAT[@label_format]
    end

    # Format in which the label(s) will be printed.
    # * null (“Instructions”)
    # * NOI (“No Instructions”)
    # * TWO (“Double Label”)
    def label_format=(v)
      @label_format = validate_set_inclusion(v, LABEL_FORMAT.keys, __method__)
    end

    # The intended recipient of the returned package (e.g. Returns Department).
    # <em>Optional</em>.
    def attention=(v)
      @attention = validate_string_length(v, 38, __method__)
    end

    # The name of the company to which the package is being returned.
    # <em>Optional</em>.
    def company_name=(v)
      @company_name = validate_string_length(v, 38, __method__)
    end

    # <b>Required</b>.
    def merchant_account_id=(v)
      @merchant_account_id = nil
      if v.to_i > 0
        @merchant_account_id = v
      else
        raise USPSValidationError, "#{__method__} must be a valid positive integer, found value '#{v}'."
      end
    end

    # <b>Required</b>.
    def mid=(v)
      @mid = nil
      if v.to_s =~ /^\d{6,9}$/
        @mid = v
      else
        raise USPSValidationError, "#{__method__} must be a valid integer between 6 and 9 digits in length, found value '#{v}'."
      end
    end

    # Urbanization of customer returning the package (only applicable to Puerto Rico addresses).
    # <em>Optional</em>.
    def customer_urbanization=(v)
      @customer_urbanization = validate_string_length(v, 32, __method__)
    end

    # Name of customer returning package.
    # <b>Required</b>.
    def customer_name=(v)
      @customer_name = validate_range(v, 1, 32, __method__)
    end

    # Address of the customer returning the package.
    # <b>Required</b>.
    def customer_address1=(v)
      @customer_address1 = validate_range(v, 1, 32, __method__)
    end

    # Secondary address unit designator / number of customer
    # returning the package. (such as an apartment or
    # suite number, e.g. APT 202, STE 100)
    def customer_address2=(v)
      @customer_address2 = validate_range(v, 0, 32, __method__)
    end

    # City of customer returning the package.
    # <b>Required</b>.
    def customer_city=(v)
      @customer_city = validate_range(v, 1, 32, __method__)
    end

    # State of customer returning the package.
    # <b>Required</b>.
    def customer_state=(v)
      @customer_state = nil
      if (v = sanitize(v)) && v =~ /^[a-zA-Z]{2}$/
        @customer_state = v
      else
        raise USPSValidationError, "#{__method__} must be a String 2 chars in length, found value '#{v}'."
      end
    end

    # Zipcode of customer returning the package.
    # According to the USPS documentation, Zipcode is optional
    # unless <tt>address_override_notification</tt> is true
    # and <tt>address_validation</tt> is set to false.
    # It's probably just easier to require Zipcodes.
    # <b>Required</b>.
    def customer_zipcode=(v)
      @customer_zipcode = nil
      if (v = sanitize(v))
        v = v[0..4]
        if v =~ /^\d{5}$/
          @customer_zipcode = v
        end
      else
        raise USPSValidationError, "#{__method__} must be a 5 digit number, found value '#{v}'."
      end
    end

    def verify_or_raise_required
      %w(customer_name customer_address1 customer_city customer_state
         customer_zipcode label_format label_definition service_type_code
         call_center_or_self_service).each do |attr|
        raise USPSMissingRequiredTagError.new(attr.camelize, attr) unless send(attr.to_sym)
      end
      # Safer than using inflection acroynms
      raise USPSMissingRequiredTagError.new("MID", "mid") unless mid
      raise USPSMissingRequiredTagError.new("MerchantAccountID", "merchant_account_id") unless merchant_account_id
    end

    def to_xml
      xml_builder = Nokogiri::XML::Builder.new do |xml|
        xml.ExternalReturnLabelRequest do
          xml.CustomerName { xml.text(customer_name) }
          xml.CustomerAddress1 { xml.text(customer_address1) }
          xml.CustomerAddress2 { xml.text(customer_address2) } if customer_address2
          xml.CustomerCity { xml.text(customer_city) }
          xml.CustomerState { xml.text(customer_state) }
          xml.CustomerZipCode { xml.text(customer_zipcode) } if customer_zipcode
          xml.CustomerUrbanization { xml.text(customer_urbanization) } if customer_urbanization

          xml.MerchantAccountID { xml.text(merchant_account_id) }
          xml.MID { xml.text(mid) }

          xml.SenderName { xml.text(sender_name) } if sender_name
          xml.SenderEmail { xml.text(sender_email) } if sender_email

          xml.RecipientName { xml.text(recipient_name) } if recipient_name
          xml.RecipientEmail { xml.text(recipient_email) } if recipient_email
          xml.RecipientBcc { xml.text(recipient_bcc) } if recipient_bcc

          xml.LabelFormat { xml.text(label_format) } if label_format
          xml.LabelDefinition { xml.text(label_definition) } if label_definition
          xml.ServiceTypeCode { xml.text(service_type_code) } if service_type_code

          xml.CompanyName { xml.text(company_name) } if company_name
          xml.Attention { xml.text(attention) } if attention

          xml.CallCenterOrSelfService { xml.text(call_center_or_self_service) }

          xml.MerchandiseDescription { xml.text(merchandise_description) } if merchandise_description
          xml.InsuranceAmount { xml.text(insurance_amount) } if insurance_amount

          xml.AddressOverrideNotification { xml.text(!!address_override_notification) }

          xml.PackageInformation { xml.text(packaging_information) } if packaging_information
          xml.PackageInformation2 { xml.text(packaging_information2) } if packaging_information2

          xml.ImageType { xml.text(image_type) } if image_type
          xml.AddressValidation { xml.text(!!address_validation) }

        end
      end
      xml_builder.to_xml
    end

    private

    def to_bool(v, default = false)
      v = v.to_s
      if v =~ (/(true|yes|1)$/i)
        true
      elsif v =~ (/(false|no|0)$/i)
        false
      else
        default
      end
    end

    def sanitize(v)
      if v.is_a?(String)
        v.strip!
        v[0..CAP_STRING_LEN - 1]
      else
        nil
      end
    end

    def validate_range(v, min, max, meth)
      if (v = sanitize(v).to_s) && ((min.to_i)..(max.to_i)).include?(v.length)
        if v.length == 0
          nil
        else
          v
        end
      else
        raise USPSValidationError, "#{meth} must be a String between #{min.to_i} and #{max.to_i} chars in length, found value '#{v}'."
      end
    end

    def validate_string_length(s, max_len, meth)
      if (s = sanitize(s)) && s.length <= max_len.to_i
        s
      else
        raise USPSValidationError, "#{meth} must be a String no more than #{max_len} chars in length, found value '#{s}'."
      end
    end

    def validate_set_inclusion(v, set, meth)
      if set.respond_to?(:include?) && set.include?(v)
        v
      else
        raise USPSValidationError, "#{v} is not valid in #{meth}, try any of the following: #{(set.respond_to?(:join) && set.join(',')) || ''}"
      end
    end

    def validate_email(v, meth)
      if (v = sanitize(v)) && v =~ USPS_EMAIL_REGEX
        v
      else
        raise USPSValidationError, "'#{v}' is not a valid e-mail in #{meth}"
      end
    end

  end
end
