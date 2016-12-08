require 'test_helper'

class BenchmarkTest < ActiveSupport::TestCase
  include ActiveShipping::Test::Fixtures

  def setup
    @carrier = BenchmarkCarrier.new
  end

  def test_benchmark_response_is_valid
    @carrier.stubs(:generate_simulated_lag).returns(0)
    response = @carrier.find_rates(location_fixtures[:london], location_fixtures[:new_york], package_fixtures[:wii])
    assert_equal 1, response.rates.count
    rate = response.rates.first
    assert_equal "Free Benchmark Shipping", rate.service_name
    assert_equal 0, rate.price
  end
end
