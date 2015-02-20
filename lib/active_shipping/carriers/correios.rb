# -*- encoding utf-8 -*-

module ActiveShipping
  class Correios < Carrier

    cattr_reader :name
    @@name = "Correios do Brasil"

    def find_rates(origin, destination, packages, options = {})
      options = @options.merge(options)

      request = CorreiosRequest.new(origin, destination, packages, options)
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
      '81833' => '(Grupo 2) e-SEDEX, com contrato', 
      '81850' => '(Grupo 3) e-SEDEX, com contrato' 
    }.freeze

    protected

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

      def initialize(origin, destination, packages, options)
        @options = options
        @origin = origin
        @destination = destination

        packages = packages.map do |package| 
          CorreiosPackage.new(package, 1)
        end

        @params = {
          company_id: '',
          password: '',
          service_type: service_type, 
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

      def create_response(raw_xmls)
        correios_response = CorreiosResponse.new(self, raw_xmls)
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

      def service_type
        @options[:services].nil? ? '41106,40010' : @options[:services].join(',')
      end

    end


    class CorreiosRateResponse < ActiveShipping::RateResponse
      attr_reader :raw_responses

      def initialize(success, message, params = {}, options = {})
        @raw_responses = options[:raw_responses]
        super  
      end
    end 

    class CorreiosResponse

      def initialize(request, raw_xmls)
        @request = request
        @raw_xmls = raw_xmls
        @documents = raw_xmls.map { |xml| Nokogiri::XML(xml) }
      end

      def rate_response
        @rates = rates
        CorreiosRateResponse.new(true, 'success', params_options, response_options) 
      rescue => error
        CorreiosRateResponse.new(false, error.message, {}, response_options)
      end

      private

      def response_options
        { 
          :rates => @rates,
          :raw_responses => @raw_xmls
        }  
      end

      def params_options
        { :responses => @documents }
      end

      def normalized_services
        services = @documents.map { |document| document.root.elements }.flatten
        services = services.group_by do |service_xml| 
          raise(error_message(service_xml)) if error?(service_xml)
          service_code(service_xml)
        end
      end

      def rates_array
        services = normalized_services.map do |service_id, elements|
          total_price = elements.sum { |element| price(element) }
          { :service_code => service_id, :total_price => total_price, :currency => "BRL" }
        end
      end
      
      def rates
        rates_array.map { |rate_hash| create_rate_estimate(rate_hash) }
      end

      def create_rate_estimate(rate_hash)
        RateEstimate.new(@request.origin, @request.destination, Correios.name, AVAILABLE_SERVICES[rate_hash[:service_code]], rate_hash) 
      end 

      def error?(xml_item)
        text = error(xml_item)
        !text.empty? && text != "0"
      end

      def error(xml_item)
        xml_item.css('Erro').text
      end

      def error_message(xml_item)
        xml_item.css('MsgErro').text
      end

      def service_code(xml_item)
         xml_item.css('Codigo').text
      end

      def price(xml_item)
        xml_item.css('Valor').text.gsub(',', '.').to_f
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
