# -*- coding: utf-8 -*-
require "test_helper"

class CorreiosTest < Minitest::Test
  include ActiveShipping::Test::Fixtures

  def setup
    @carrier = Correios.new

    @saopaulo = Location.new(:zip => "01415000")
    @patosdeminas = Location.new(:zip => "38700000")

    @book = package_fixtures[:book]
    @poster = package_fixtures[:poster]

    @response_clothes = xml_fixture('correios/clothes_response')
    @response_shoes = xml_fixture('correios/shoes_response')
    @response_book_success = xml_fixture('correios/book_response')
    @response_poster_success = xml_fixture('correios/poster_response')
    @response_book_invalid = xml_fixture('correios/book_response_invalid')
  end

  def test_book_request
    @carrier.expects(:perform).returns([@response_book_success])
    response = @carrier.find_rates(@saopaulo, @patosdeminas, [@book])

    [
      "sCepOrigem=01415000",
      "sCepDestino=38700000",
      "nVlPeso=0.25",
      "nCdFormato=1",
      "nVlComprimento=19",
      "nVlAltura=2",
      "nVlLargura=14",
      "nVlDiametro=0"
    ].each do |query_param|
      assert_match query_param, response.urls.first
    end
  end

  def test_poster_request
    @carrier.expects(:perform).returns([@response_poster_success])
    response = @carrier.find_rates(@saopaulo, @patosdeminas, [@poster])

    [
      "sCepOrigem=01415000",
      "sCepDestino=38700000",
      "nVlPeso=0.1",
      "nCdFormato=1",
      "nVlComprimento=93",
      "nVlAltura=10",
      "nVlLargura=10",
      "nVlDiametro=10"
    ].each do |query_param|
      assert_match query_param, response.urls.first
    end
  end

  def test_poster_and_book_request
    @carrier.expects(:perform).returns([@response_poster_success, @response_book_success])
    response = @carrier.find_rates(@saopaulo, @patosdeminas, [@poster, @book])

    [
      "sCepOrigem=01415000",
      "sCepDestino=38700000",
      "nVlPeso=0.1",
      "nCdFormato=1",
      "nVlComprimento=93",
      "nVlAltura=10",
      "nVlLargura=10",
      "nVlDiametro=10"
    ].each do |query_param|
      assert_match query_param, response.urls.first
    end

    [
      "sCepOrigem=01415000",
      "sCepDestino=38700000",
      "nVlPeso=0.25",
      "nCdFormato=1",
      "nVlComprimento=19",
      "nVlAltura=2",
      "nVlLargura=14",
      "nVlDiametro=0"
    ].each do |query_param|
      assert_match query_param, response.urls.last
    end
  end

  def test_book_request_with_specific_services
    @carrier.expects(:perform).returns([@response_book_success])
    response = @carrier.find_rates(@saopaulo, @patosdeminas, [@book], :services => [41106, 40010, 40215])

    [
      "nCdServico=41106%2C40010%2C40215",
      "sCepOrigem=01415000",
      "sCepDestino=38700000",
      "nVlPeso=0.25",
      "nCdFormato=1",
      "nVlComprimento=19",
      "nVlAltura=2",
      "nVlLargura=14",
      "nVlDiametro=0"
    ].each do |query_param|
      assert_match query_param, response.urls.first
    end
  end

  def test_book_request_with_option_params
    options = {
      :company_id => 1010,
      :password => 123123,
      :declared_value_extra => 10.50,
      :delivery_notice_extra => true,
      :mao_propria_extra => true
    }

    @carrier.expects(:perform).returns([@response_book_success])
    response = @carrier.find_rates(@saopaulo, @patosdeminas, [@book], options)

    [
      "nCdEmpresa=1010",
      "sDsSenha=123123",
      "sCdMaoPropria=S",
      "nVlValorDeclarado=10%2C5",
      "sCdAvisoRecebimento=S",
      "nCdServico=41106%2C40010",
      "sCepOrigem=01415000",
      "sCepDestino=38700000",
      "nVlPeso=0.25",
      "nCdFormato=1",
      "nVlComprimento=19",
      "nVlAltura=2",
      "nVlLargura=14",
      "nVlDiametro=0"
    ].each do |query_param|
      assert_match query_param, response.urls.first
    end

  end

  def test_book_response
    @carrier.stubs(:perform).returns([@response_book_success])
    response = @carrier.find_rates(@saopaulo, @patosdeminas, [@book])

    assert_equal 1, response.rates.size
    assert_equal [10520], response.rates.map(&:price)
  end

  def test_poster_response
    @carrier.stubs(:perform).returns([@response_poster_success])
    response = @carrier.find_rates(@saopaulo, @patosdeminas, [@poster])

    assert_equal 2, response.rates.size
    assert_equal [1000, 2000], response.rates.map(&:price)
  end

  def test_two_books_response
    @carrier.stubs(:perform).returns([@response_book_success, @response_book_success])
    response = @carrier.find_rates(@saopaulo, @patosdeminas, [@book, @book])

    assert_equal 1, response.rates.size
    assert_equal [21040], response.rates.map(&:price)
  end

  def test_two_posters_response
    @carrier.stubs(:perform).returns([@response_poster_success, @response_poster_success])
    response = @carrier.find_rates(@saopaulo, @patosdeminas, [@poster, @poster])

    assert_equal 2, response.rates.size
    assert_equal [2000, 4000], response.rates.map(&:price)
  end

  def test_response_parsing
    @carrier.stubs(:perform).returns([@response_clothes, @response_shoes])
    response = @carrier.find_rates(@saopaulo, @patosdeminas, [@book, @book])
    service_codes = [41106, 41300, 40215, 81019]
    service_names = [
      'PAC sem contrato',
      'PAC para grandes formatos',
      'SEDEX 10, sem contrato',
      'e-SEDEX, com contrato'
    ]

    assert_equal service_codes, response.rates.map(&:service_code)
    assert_equal service_names, response.rates.map(&:service_name)
  end

  def test_response_params_options
    @carrier.stubs(:perform).returns([@response_book_success])
    response = @carrier.find_rates(@saopaulo, @patosdeminas, [@book])

    assert_equal [Nokogiri::XML::Document], response.params['responses'].map(&:class)
    assert_equal [Nokogiri::XML(@response_book_success).to_xml], response.params['responses'].map(&:to_xml)
  end

  def test_book_invalid_response
    error = assert_raises(ActiveShipping::ResponseError) do
      @carrier.stubs(:perform).returns([@response_book_invalid])
      @carrier.find_rates(@saopaulo, @patosdeminas, [@book])
    end

    assert_equal "CEP de origem invalido", error.message
    assert_equal error.response.raw_responses, [@response_book_invalid]
    assert_equal Hash.new, error.response.params
  end

  def test_valid_book_and_invalid_book_response
    error = assert_raises(ActiveShipping::ResponseError) do
      @carrier.stubs(:perform).returns([@response_book_success, @response_book_invalid])
      @carrier.find_rates(@saopaulo, @patosdeminas, [@book, @book])
    end

    assert_equal "CEP de origem invalido", error.message
    assert_equal error.response.raw_responses, [@response_book_success, @response_book_invalid]
    assert_equal Hash.new, error.response.params
  end

  def test_show_available_services
    services = Correios.available_services

    assert_kind_of Hash, services
    assert_equal 19, services.size
    assert_equal 'PAC sem contrato', services[41106]
    assert_equal 'PAC com contrato', services[41068]
    assert_equal 'PAC para grandes formatos', services[41300]
    assert_equal 'SEDEX sem contrato', services[40010]
    assert_equal 'SEDEX a Cobrar, sem contrato', services[40045]
    assert_equal 'SEDEX a Cobrar, com contrato', services[40126]
    assert_equal 'SEDEX 10, sem contrato', services[40215]
    assert_equal 'SEDEX Hoje, sem contrato', services[40290]
    assert_equal 'SEDEX com contrato', services[40096]
    assert_equal 'SEDEX com contrato', services[40436]
    assert_equal 'SEDEX com contrato', services[40444]
    assert_equal 'SEDEX com contrato', services[40568]
    assert_equal 'SEDEX com contrato', services[40606]
    assert_equal 'e-SEDEX, com contrato', services[81019]
    assert_equal 'e-SEDEX Prioritário, com contrato', services[81027]
    assert_equal 'e-SEDEX Express, com contrato', services[81035]
    assert_equal '(Grupo 1) e-SEDEX, com contrato', services[81868]
    assert_equal '(Grupo 2) e-SEDEX, com contrato', services[81833]
    assert_equal '(Grupo 3) e-SEDEX, com contrato', services[81850]
  end

  def test_maximum_address_field_length
    assert_equal 255, @carrier.maximum_address_field_length
  end
end
