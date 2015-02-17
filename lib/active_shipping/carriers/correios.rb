# -*- encoding utf-8 -*-

module ActiveShipping
  class Correios < Carrier

    cattr_reader :name
    @@name = "Correios do Brasil"

    def find_rates(origin, destination, packages, options = {})
      options = @options.merge(options)

      request = CorreiosRequest.new(origin, destination, packages)
      response = request.create_response(perform(request.urls))
      
      response
    end

    protected

    AVAILABLE_SERVICES = {
      '41106' => 'PAC sem contrato', 
      '41068' => 'PAC com contrato', 
      '41300' => 'PAC para grandes formatos', 
      '40010' => 'SEDEX sem contrato', 
      '40045' => 'SEDEX a Cobrar, sem contrato', 
      '40126' => 'SEDEX a Cobrar, com contrato', 
      '40215' => 'SEDEX 10, sem contrato', 
      '40290' => 'SEDEX Hoje, sem contrato', 
      '40096' => 'SEDEX com contrato', 
      '40436' => 'SEDEX com contrato', 
      '40444' => 'SEDEX com contrato', 
      '40568' => 'SEDEX com contrato', 
      '40606' => 'SEDEX com contrato', 
      '81019' => 'e-SEDEX, com contrato', 
      '81027' => 'e-SEDEX Prioritário, com contrato', 
      '81035' => 'e-SEDEX Express, com contrato', 
      '81868' => '(Grupo 1) e-SEDEX, com contrato',
      '81833' => '(Grupo 2) e-SEDEX, com contrato' 
      '81850' => '(Grupo 3) e-SEDEX, com contrato' 
    }.freeze

    def perform(urls)
      urls.map { |url| ssl_get(url) }
    end

    class CorreiosRequest
      
      URL = "http://ws.correios.com.br/calculador/CalcPrecoPrazo.aspx"

      RETURN_TYPE = 'xml'
      RETURN_INFORMATION_TYPE = {
        :prices => '1',
        :time => '2',
        :prices_and_time => '3'
      }

      attr_reader :origin, :destination, :urls

      def initialize(origin, destination, packages)
        @origin = origin
        @destination = destination

        packages = packages.map do |package| 
          CorreiosPackage.new(package, 1)
        end

        @params = {
          company_id: '',
          password: '',
          service_type: '41106',
          origin_zip: origin.zip,
          destination_zip: destination.zip,
          special_service: 'N',
          declared_value: '0',
          delivery_notice: 'N',
          return_type: RETURN_TYPE,
          return_information: RETURN_INFORMATION_TYPE[:prices]
        }
        @urls = packages.map { |package| create_url(package) }
      end

      def create_response(xmls_raw)
        correios_response = CorreiosResponse.new(self, xmls_raw)
        correios_response.rate_response
      end

      private

      def params(package)
        @params.merge(package.params)
      end

      def query_string(params)        
        "nCdEmpresa=#{params[:company_id]}&" +
        "sDsSenha=#{params[:password]}&" +
        "nCdServico=#{params[:service_type]}&" +
        "sCepOrigem=#{params[:origin_zip]}&" +
        "sCepDestino=#{params[:destination_zip]}&" +
        "nVlPeso=#{params[:weight]}&" +
        "nCdFormato=#{params[:format]}&" +
        "nVlComprimento=#{params[:length]}&" +
        "nVlAltura=#{params[:height]}&" +
        "nVlLargura=#{params[:width]}&" +
        "nVlDiametro=#{params[:diameter]}&" +
        "sCdMaoPropria=#{params[:special_service]}&" +
        "nVlValorDeclarado=#{params[:declared_value]}&" +
        "sCdAvisoRecebimento=#{params[:delivery_notice]}&" + 
        "nIndicaCalculo=#{params[:return_information]}&" +
        "StrRetorno=#{params[:return_type]}"
      end

      def create_url(package)
        "#{URL}?#{query_string(params(package))}"
      end

    end

    class CorreiosResponse

      def initialize(request, xmls)
        @request = request
        @document = Nokogiri::XML(xml)
      end

      def rate_response
        RateResponse.new(success?, message, params_options, response_options) 
      end

      private

      def response_options
        { :rates => rates }  
      end

      def params_options
        { :responses => responses }  
      end

      def responses
        Hash.from_xml(@document.to_s) 
      end

      def rates
        list = @document.css('cServico')  
        
        rates = list.map { |xml_item| create_rate_estimate(xml_item) }
        rates
      end

      def create_rate_estimate(xml_item)
        service_params = create_service(xml_item)
        rate_estimate_params = create_rate_estimate_params(xml)

        RateEstimate.new(@request.origin, @request.destination, @@name, service_name, rate_estimate_params) 
      end

      def service_name(xml_item)
        AVAILABLE_SERVICES[service_code(xml_item)]  
      end

      def rate_estimate_params(xml_item)
        {
          :total_price => total_price(xml_item),
          :currency => "R$",
          :service_code => service_code(xml_item) 
        }  
      end

      def service_code(xml_item)
         xml_item.css('Codigo').text
      end

      def price(xml_item)
        xml_item.css('Valor').text.gsub(',', '.').to_f
      end

      def success?
        @document.css('Erro').text.nil?  
      end

      def message
        if success?
          "success"
        else
          "Problem"
        end
      end

    end

    class CorreiosPackage
      attr_reader :params

      FORMAT = {
        :package => 1,
        :roll => 2, 
        :envelope => 3
      }

      def initialize(package, format)
        @package = package

        @params = { 
          :format => format,
          :weight => weight, 
          :width => width, 
          :length => length, 
          :height => height(format), 
          :diameter => diameter
        }
      end

      private 

      def weight
        @package.kg
      end

      def width
        return 0 if @package.cylinder?
        @package.cm(:width)
      end

      def length
        @package.cm(:length)
      end

      def height(format)
        return 0 if format == FORMAT[:envelope] || @package.cylinder?
        @package.cm(:height)
      end

      def diameter
        return 0 unless @package.cylinder?  
        @package.cm(:width)
      end

    end

  end
end
