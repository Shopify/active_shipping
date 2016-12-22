module HolidayHelpers
  class MissingConfigurationError < RuntimeError; end

  HOLIDAYS = {
    ups: { # https://compass.ups.com/ups-holiday-schedule-2016/
      "2016" => [
        { month: 1,  day: 1  },
        { month: 5,  day: 30 },
        { month: 6,  day: 4  },
        { month: 9,  day: 5  },
        { month: 11, day: 24 },
        { month: 12, day: 26 },
      ],
    }
  }

  def with_holidays(carrier, year=Date.current.year)
    holiday_config = fetch_holidays(carrier, year)

    BusinessTime::Config.with(holidays: holiday_config) do
      yield
    end

  rescue MissingConfigurationError
    self.logger.warn(
      "[HolidayHelpers] Missing holiday configuration. You need to update test/helpers/holiday_helpers.rb. "\
      "test: #{self}, carrier: #{carrier}, year: #{year}")
    yield
  end

  private

  def fetch_holidays(carrier, year)
    carrier_holiday_config = case carrier
    when :ups
      HOLIDAYS[carrier]
    else
      raise MissingConfigurationError
    end
    raise MissingConfigurationError unless carrier_holiday_config.include?(year.to_s)

    carrier_holiday_config[year.to_s].map do |holiday|
      Date.new(year, holiday[:month], holiday[:day])
    end
  end
end
