require 'test_helper'

class TestHelper < MiniTest::Unit::TestCase
  def test_response_content_error_message
    content_error = ResponseContentError.new(StandardError.new("something went wrong"), "omg omg omg")
    assert_equal "something went wrong \n\nomg omg omg", content_error.message
  end
end