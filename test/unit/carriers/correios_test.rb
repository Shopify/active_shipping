require "test_helper"

class CorreiosTest < Minitest::Test
  include ActiveShipping::Test::Fixtures

  def setup
    @carrier = Correios.new

    @saopaulo = Location.new(:zip => "01415000")
    @patosdeminas = Location.new(:zip => "38700000")

    @book = package_fixtures[:book] 
    @poster = package_fixtures[:poster]
    
    @response_book_success = xml_fixture('correios/book_response')
    @response_poster_success = xml_fixture('correios/poster_response')
  end

  def test_book_request
    url = "http://ws.correios.com.br/calculador/CalcPrecoPrazo.aspx?nCdEmpresa=&sDsSenha=&nCdServico=41106&sCepOrigem=01415000&sCepDestino=38700000&nVlPeso=0.25&nCdFormato=1&nVlComprimento=19&nVlAltura=2&nVlLargura=14&nVlDiametro=0&sCdMaoPropria=N&nVlValorDeclarado=0&sCdAvisoRecebimento=N&nIndicaCalculo=1&StrRetorno=xml"

    @carrier.expects(:perform).with([url]).returns([@response_book_success])
    @carrier.find_rates(@saopaulo, @patosdeminas, [@book])
  end

  def test_poster_request
    url = "http://ws.correios.com.br/calculador/CalcPrecoPrazo.aspx?nCdEmpresa=&sDsSenha=&nCdServico=41106&sCepOrigem=01415000&sCepDestino=38700000&nVlPeso=0.1&nCdFormato=1&nVlComprimento=93&nVlAltura=0&nVlLargura=0&nVlDiametro=10&sCdMaoPropria=N&nVlValorDeclarado=0&sCdAvisoRecebimento=N&nIndicaCalculo=1&StrRetorno=xml"

    @carrier.expects(:perform).with([url]).returns([@response_poster_success])
    @carrier.find_rates(@saopaulo, @patosdeminas, [@poster])
  end

  def test_poster_and_book_request 
    urls = [
      "http://ws.correios.com.br/calculador/CalcPrecoPrazo.aspx?nCdEmpresa=&sDsSenha=&nCdServico=41106&sCepOrigem=01415000&sCepDestino=38700000&nVlPeso=0.1&nCdFormato=1&nVlComprimento=93&nVlAltura=0&nVlLargura=0&nVlDiametro=10&sCdMaoPropria=N&nVlValorDeclarado=0&sCdAvisoRecebimento=N&nIndicaCalculo=1&StrRetorno=xml",
      "http://ws.correios.com.br/calculador/CalcPrecoPrazo.aspx?nCdEmpresa=&sDsSenha=&nCdServico=41106&sCepOrigem=01415000&sCepDestino=38700000&nVlPeso=0.25&nCdFormato=1&nVlComprimento=19&nVlAltura=2&nVlLargura=14&nVlDiametro=0&sCdMaoPropria=N&nVlValorDeclarado=0&sCdAvisoRecebimento=N&nIndicaCalculo=1&StrRetorno=xml"
    ]

    @carrier.expects(:perform).with(urls).returns([@response_poster_success, @response_book_success])
    @carrier.find_rates(@saopaulo, @patosdeminas, [@poster, @book])
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

  def test_invalid_response
    @carrier.stubs(:perform).returns([@response_book_invalid])
    response = @carrier.find_rates(@saopaulo, @patosdeminas, [@book])


  end

end
