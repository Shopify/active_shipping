require "benchmark"
require File.dirname(__FILE__) + "/../lib/xml_node"

class XmlNode
  def to_xml_as_array
    xml = []
    document = REXML::Document.new
    document << REXML::XMLDecl.new('1.0')
    document << @element
    document.write( xml, 0)
    xml.to_s
  end

  def to_xml_no_format
    xml = ''
    document = REXML::Document.new
    document << REXML::XMLDecl.new('1.0')
    document << @element
    document.write( xml)
    xml
  end
end

TESTS = 10000

Benchmark.bmbm do |results|
  results.report { TESTS.times do XmlNode.new('feed') { |n| n << XmlNode.new('element', 'test'); n << XmlNode.new('element') }.to_xml end }
  results.report { TESTS.times do XmlNode.new('feed') { |n| n << XmlNode.new('element', 'test'); n << XmlNode.new('element') }.to_xml_as_array end }
  results.report { TESTS.times do XmlNode.new('feed') { |n| n << XmlNode.new('element', 'test'); n << XmlNode.new('element') }.to_xml_no_format end }
end
