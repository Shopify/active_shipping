module ActiveShipping

  # Class representing a shipping option with estimated price.
  #
  # @!attribute origin
  #   The origin of the shipment
  #   @return [ActiveShipping::Location]
  #
  # @!attribute destination
  #   The destination of the shipment
  #   @return [ActiveShipping::Location]
  #
  # @!attribute package_rates
  #   A list of rates for all the packages in the shipment
  #   @return [Array<{:rate => Integer, :package => ActiveShipping::Package}>]
  #
  # @!attribute carrier
  #   The name of the carrier (e.g. 'USPS', 'FedEx')
  #   @return [String]
  #   @see ActiveShipping::Carrier.name
  #
  # @!attribute service_name
  #   The name of the shipping service (e.g. 'First Class Ground')
  #   @return [String]
  #
  # @!attribute service_code
  #   The code of the shipping service
  #   @return [String]
  #
  # @!attribute description
  #   Public description of the shipping service (e.g. '2 days delivery')
  #   @return [String]
  #
  # @!attribute shipping_date
  #   The date on which the shipment will be expected. Normally, this means that the
  #   delivery date range can only be promised if the shipment is handed over on or
  #   before this date.
  #   @return [Date]
  #
  # @!attribute delivery_date
  #   The date on which the shipment will be delivered. This is usually only available
  #   for express shipments; in other cases a {#delivery_range} is given instead.
  #   @return [Date]
  #
  # @!attribute delivery_range
  #   The minimum and maximum date of when the shipment is expected to be delivered
  #   @return [Array<Date>]
  #
  # @!attribute currency
  #   ISO4217 currency code of the quoted rate estimates (e.g. `CAD`, `EUR`, or `USD`)
  #   @return [String]
  #   @see http://en.wikipedia.org/wiki/ISO_4217
  #
  # @!attribute negotiated_rate
  #   The negotiated rate in cents
  #   @return [Integer]
  #
  # @!attribute compare_price
  #   The comparable price in cents
  #   @return [Integer]
  #
  # @!attribute phone_required
  #   Specifies if a phone number is required for the shipping rate
  #   @return [Boolean]
  #
  # @!attribute insurance_price
  #   The price of insurance in cents
  #   @return [Integer]
  #
  # @!attribute delivery_category
  #   The general classification of the delivery method
  #   @return [String]
  #
  # @!attribute shipment_options
  #   Additional priced options bundled with the given rate estimate with price in cents
  #   @return [Array<{ code: String, price: Integer }>]
  #
  # @!attribute charge_items
  #   Breakdown of a shipping rate's price with amounts in cents.
  #   @return [Array<{ group: String, code: String, name: String, description: String, amount: Integer }>]
  #
  class RateEstimate
    attr_accessor :origin, :destination, :package_rates,
                :carrier, :service_name, :service_code, :description,
                :shipping_date, :delivery_date, :delivery_range,
                :currency, :negotiated_rate, :insurance_price,
                :estimate_reference, :expires_at, :pickup_time,
                :compare_price, :phone_required, :delivery_category,
                :shipment_options, :charge_items

    def initialize(origin, destination, carrier, service_name, options = {})
      self.origin, self.destination, self.carrier, self.service_name = origin, destination, carrier, service_name
      self.service_code = options[:service_code]
      self.description = options[:description]
      self.estimate_reference = options[:estimate_reference]
      self.pickup_time = options[:pickup_time]
      self.expires_at = options[:expires_at]
      if options[:package_rates]
        self.package_rates = options[:package_rates].map { |p| p.update(:rate => Package.cents_from(p[:rate])) }
      else
        self.package_rates = Array(options[:packages]).map { |p| {:package => p} }
      end
      self.total_price = options[:total_price]
      self.negotiated_rate = options[:negotiated_rate]
      self.compare_price = options[:compare_price]
      self.phone_required = options[:phone_required]
      self.currency = options[:currency]
      self.delivery_range = options[:delivery_range]
      self.shipping_date = options[:shipping_date]
      self.delivery_date = @delivery_range.last
      self.insurance_price = options[:insurance_price]
      self.delivery_category = options[:delivery_category]
      self.shipment_options = options[:shipment_options] || []
      self.charge_items = options[:charge_items] || []
    end

    # The total price of the shipments in cents.
    # @return [Integer]
    def total_price
      @total_price || @package_rates.sum { |pr| pr[:rate] }
    rescue NoMethodError
      raise ArgumentError.new("RateEstimate must have a total_price set, or have a full set of valid package rates.")
    end
    alias_method :price, :total_price

    # Adds a package to this rate estimate
    # @param package [ActiveShipping::Package] The package to add.
    # @param rate [#cents, Float, String, nil] The rate for this package. This is only required if
    #   there is no total price for this shipment
    # @return [self]
    def add(package, rate = nil)
      cents = Package.cents_from(rate)
      raise ArgumentError.new("New packages must have valid rate information since this RateEstimate has no total_price set.") if cents.nil? and total_price.nil?
      @package_rates << {:package => package, :rate => cents}
      self
    end

    # The list of packages for which rate estimates are given.
    # @return [Array<ActiveShipping::Package>]
    def packages
      package_rates.map { |p| p[:package] }
    end

    # The number of packages for which rate estimates are given.
    # @return [Integer]
    def package_count
      package_rates.length
    end

    protected

    def delivery_range=(delivery_range)
      @delivery_range = delivery_range ? delivery_range.map { |date| date_for(date) }.compact : []
    end

    def total_price=(total_price)
      @total_price = Package.cents_from(total_price)
    end

    def negotiated_rate=(negotiated_rate)
      @negotiated_rate = negotiated_rate ? Package.cents_from(negotiated_rate) : nil
    end

    def compare_price=(compare_price)
      @compare_price = compare_price ? Package.cents_from(compare_price) : nil
    end

    def currency=(currency)
      @currency = ActiveUtils::CurrencyCode.standardize(currency)
    end

    def phone_required=(phone_required)
      @phone_required = !!phone_required
    end

    def shipping_date=(shipping_date)
      @shipping_date = date_for(shipping_date)
    end

    def insurance_price=(insurance_price)
      @insurance_price = Package.cents_from(insurance_price)
    end

    private

    # Returns a Date object for a given input
    # @param date [String, Date, Time, DateTime, ...] The object to infer a date from.
    # @return [Date, nil] The Date object absed on the input, or `nil` if no date
    #   could be determined.
    def date_for(date)
      date && DateTime.strptime(date.to_s, "%Y-%m-%d")
    rescue ArgumentError
      nil
    end
  end
end
