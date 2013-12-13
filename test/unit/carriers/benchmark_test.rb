require 'test_helper'

class BenchmarkTest < Test::Unit::TestCase

  def setup
    @packages = TestFixtures.packages
    @locations = TestFixtures.locations
    @carrier = BenchmarkCarrier.new
  end

  def test_benchmark_response_is_valid
    @carrier.stubs(:generate_simulated_lag).returns(0)
    response = @carrier.find_rates(@locations[:london], @locations[:new_york], @packages.values_at(:wii))
    assert_equal 1, response.rates.count
    rate = response.rates.first
    assert_equal "Free Benchmark Shipping", rate.service_name
    assert_equal 0, rate.price
  end

end
