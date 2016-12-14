module ActiveShipping #:nodoc:
  class Location
    ADDRESS_TYPES = %w(residential commercial po_box)

    ATTRIBUTE_ALIASES = {
      name: [:name],
      country: [:country_code, :country],
      postal_code: [:postal_code, :zip, :postal],
      province: [:province_code, :state_code, :territory_code, :region_code, :province, :state, :territory, :region],
      city: [:city, :town],
      address1: [:address1, :address, :street],
      address2: [:address2],
      address3: [:address3],
      phone: [:phone, :phone_number],
      fax: [:fax, :fax_number],
      address_type: [:address_type],
      company_name: [:company, :company_name],
    }.freeze

    attr_reader :options,
                :country,
                :postal_code,
                :province,
                :city,
                :name,
                :address1,
                :address2,
                :address3,
                :phone,
                :fax,
                :address_type,
                :company_name

    alias_method :zip, :postal_code
    alias_method :postal, :postal_code
    alias_method :state, :province
    alias_method :territory, :province
    alias_method :region, :province
    alias_method :company, :company_name

    def initialize(options = {})
      @country = if options[:country].nil? || options[:country].is_a?(ActiveUtils::Country)
        options[:country]
      else
        ActiveUtils::Country.find(options[:country])
      end

      @postal_code = options[:postal_code] || options[:postal] || options[:zip]
      @province = options[:province] || options[:state] || options[:territory] || options[:region]
      @city = options[:city]
      @name = options[:name]
      @address1 = options[:address1]
      @address2 = options[:address2]
      @address3 = options[:address3]
      @phone = options[:phone]
      @fax = options[:fax]
      @company_name = options[:company_name] || options[:company]

      self.address_type = options[:address_type]
    end

    def self.from(object, options = {})
      return object if object.is_a?(ActiveShipping::Location)

      attributes = {}

      hash_access = begin
        object[:some_symbol]
        true
      rescue
        false
      end

      ATTRIBUTE_ALIASES.each do |attribute, aliases|
        aliases.detect do |sym|
          value = if hash_access
            object[sym]
          elsif object.respond_to?(sym)
            object.send(sym)
          end

          attributes[attribute] = value if value
        end
      end

      attributes.delete(:address_type) unless ADDRESS_TYPES.include?(attributes[:address_type].to_s)

      new(attributes.update(options))
    end

    def country_code(format = :alpha2)
      @country.nil? ? nil : @country.code(format).value
    end

    def residential?
      @address_type == 'residential'
    end

    def commercial?
      @address_type == 'commercial'
    end

    def po_box?
      @address_type == 'po_box'
    end

    def unknown?
      country_code == 'ZZ'
    end

    def address_type=(value)
      return unless value.present?
      raise ArgumentError.new("address_type must be one of #{ADDRESS_TYPES.join(', ')}") unless ADDRESS_TYPES.include?(value.to_s)
      @address_type = value.to_s
    end

    def to_hash
      {
        country: country_code,
        postal_code: postal_code,
        province: province,
        city: city,
        name: name,
        address1: address1,
        address2: address2,
        address3: address3,
        phone: phone,
        fax: fax,
        address_type: address_type,
        company_name: company_name
      }
    end

    def to_s
      prettyprint.gsub(/\n/, ' ')
    end

    def prettyprint
      chunks = [@name, @address1, @address2, @address3]
      chunks << [@city, @province, @postal_code].reject(&:blank?).join(', ')
      chunks << @country
      chunks.reject(&:blank?).join("\n")
    end

    def inspect
      string = prettyprint
      string << "\nPhone: #{@phone}" unless @phone.blank?
      string << "\nFax: #{@fax}" unless @fax.blank?
      string
    end

    # Returns the postal code as a properly formatted Zip+4 code, e.g. "77095-2233"
    def zip_plus_4
      "#{$1}-#{$2}" if /(\d{5})-?(\d{4})/ =~ @postal_code
    end

    def address2_and_3
      [address2, address3].reject(&:blank?).join(", ")
    end

    def ==(other)
      to_hash == other.to_hash
    end
  end
end
