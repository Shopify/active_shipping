require 'rubygems'
require 'active_support'
require "test/unit"

require File.dirname(__FILE__) + "/../lib/xml_node"

class TestXmlNode < Test::Unit::TestCase
  def test_parse_sanity
    assert_raise(ArgumentError) { XmlNode.parse }
    assert_nothing_raised { XmlNode.parse('<feed/>') }
  end

  def test_parse_attributes
    node = XmlNode.parse('<feed attr="1"/>')
    assert_equal '1', node['attr']
    assert_equal nil, node['attr2']
  end

  def test_parse_children
    node = XmlNode.parse('<feed><element>text</element></feed>')
    assert_equal XmlNode, node.children['element'].class
    assert_equal 'text', node.children['element'].text
  end

  def test_enumerate_children
    count = 0
    XmlNode.parse('<feed><element>text</element><element>text</element></feed>').children.each { count += 1 }
    assert_equal 2, count
  end

  def test_find_first
    xml = XmlNode.parse('<feed><elem>1</elem><elem>2</elem><elem>3</elem></feed>')
    assert_equal '1', xml.find(:first, '//elem').text
  end

  def test_find_all
    xml = XmlNode.parse('<feed><elem>1</elem><elem>2</elem><elem>3</elem></feed>')
    assert_equal %w(1 2 3), xml.find(:all, '//elem').collect(&:text)
  end
end
