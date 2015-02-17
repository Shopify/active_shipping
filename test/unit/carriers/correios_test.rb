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

    @carrier.expects(:request).with([url]).returns([])
    @carrier.find_rates(@saopaulo, @patosdeminas, [@book])
  end

  def test_poster_request
    url = "http://ws.correios.com.br/calculador/CalcPrecoPrazo.aspx?nCdEmpresa=&sDsSenha=&nCdServico=41106&sCepOrigem=01415000&sCepDestino=38700000&nVlPeso=0.1&nCdFormato=1&nVlComprimento=93&nVlAltura=0&nVlLargura=0&nVlDiametro=10&sCdMaoPropria=N&nVlValorDeclarado=0&sCdAvisoRecebimento=N&nIndicaCalculo=1&StrRetorno=xml"

    @carrier.expects(:request).with([url]).returns([])
    @carrier.find_rates(@saopaulo, @patosdeminas, [@poster])
  end

  def test_poster_and_book_request 
    urls = [
      "http://ws.correios.com.br/calculador/CalcPrecoPrazo.aspx?nCdEmpresa=&sDsSenha=&nCdServico=41106&sCepOrigem=01415000&sCepDestino=38700000&nVlPeso=0.1&nCdFormato=1&nVlComprimento=93&nVlAltura=0&nVlLargura=0&nVlDiametro=10&sCdMaoPropria=N&nVlValorDeclarado=0&sCdAvisoRecebimento=N&nIndicaCalculo=1&StrRetorno=xml",
      "http://ws.correios.com.br/calculador/CalcPrecoPrazo.aspx?nCdEmpresa=&sDsSenha=&nCdServico=41106&sCepOrigem=01415000&sCepDestino=38700000&nVlPeso=0.25&nCdFormato=1&nVlComprimento=19&nVlAltura=2&nVlLargura=14&nVlDiametro=0&sCdMaoPropria=N&nVlValorDeclarado=0&sCdAvisoRecebimento=N&nIndicaCalculo=1&StrRetorno=xml"
    ]

    @carrier.expects(:request).with(urls).returns([])
    @carrier.find_rates(@saopaulo, @patosdeminas, [@poster, @book])
  end

  def test_book_response
    @carrier.stubs(:request).returns([@response_book])
    response = @carrier.find_rates(@saopaulo, @patosdeminas, [@book])
    
    assert_equal 1, response.rates.size
    assert_equal [105.20], response.rates.map(&:price)

  end

end
