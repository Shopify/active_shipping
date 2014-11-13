require 'rubygems'
require 'active_support'
require "test/unit"

require File.dirname(__FILE__) + "/../lib/xml_node"

class TestXmlNode < Test::Unit::TestCase
  def test_init_sanity
    assert_raise(ArgumentError) { XmlNode.new }
    assert_nothing_raised { XmlNode.new('feed') }
    assert_nothing_raised { XmlNode.new('feed', 'content') }
    assert_nothing_raised { XmlNode.new('feed', :attribute => true) }
    assert_nothing_raised { XmlNode.new('feed', 'content', :attribute => true) }
  end

  def test_element_generation
    assert_equal '<feed/>', XmlNode.new('feed').to_s
    assert_equal '<feed>content</feed>', XmlNode.new('feed', 'content').to_s
    assert_equal "<feed attr='true'>content</feed>", XmlNode.new('feed', 'content', :attr => true).to_s
    assert_equal "<feed attr='true'/>", XmlNode.new('feed', :attr => true).to_s
  end

  def test_nesting
    assert_equal '<feed><element/></feed>', XmlNode.new('feed') { |n| n << XmlNode.new('element') }.to_s
    assert_equal '<feed><element><id>1</id></element></feed>', XmlNode.new('feed') { |n| n << XmlNode.new('element') { |n| n << XmlNode.new('id', '1') } }.to_s
  end

  def test_cdata
    node = XmlNode.new('feed')
    node.text = '...'
    node.cdata = 'Goodbye world'
    node.cdata = 'Hello world'

    assert_equal '<feed>...<![CDATA[Hello world]]></feed>', node.to_s
    assert_equal 'Hello world', node.cdata
    assert_equal '...', node.text
  end

  def test_text
    node = XmlNode.new('feed')
    node.text = 'Hello world'

    assert_equal '<feed>Hello world</feed>', node.to_s
    assert_equal 'Hello world', node.text
  end

  def test_attributes
    node = XmlNode.new('feed')
    node['attr'] = 1
    assert_equal '1', node['attr']
  end

  def test_namespace
    node = XmlNode.new('feed')
    node.namespace 'http://www.w3.org/2005/Atom'
    assert_equal "<feed xmlns='http://www.w3.org/2005/Atom'/>", node.to_s
  end

  def test_named_namespace
    node = XmlNode.new('feed')
    node.namespace :opensearch, 'http://a9.com/-/spec/opensearch/1.1/'
    assert_equal "<feed xmlns:opensearch='http://a9.com/-/spec/opensearch/1.1/'/>", node.to_s
  end

  def test_generate_nice_xml
    assert_equal "<?xml version='1.0'?>\n<feed>\n  <element>test</element>\n  <element/>\n</feed>", XmlNode.new('feed') { |n| n << XmlNode.new('element', 'test'); n << XmlNode.new('element') }.to_xml
  end

  def test_add_array_of_nodes
    assert_equal '<feed><e>1</e><e>2</e><e>3</e></feed>', XmlNode.new('feed') { |n| n << [1, 2, 3].collect { |i| XmlNode.new('e', i) } }.to_s
  end

  def test_boolean
    assert_equal '<boolean>true</boolean>', XmlNode.new('boolean', true).to_s
    assert_equal '<boolean>false</boolean>', XmlNode.new('boolean', false).to_s
  end

  def test_nil
    assert_equal '<nil/>', XmlNode.new('nil', nil).to_s
  end

  def test_dont_choke_on_nil_pushing
    feed = XmlNode.new 'feed'
    assert_nothing_raised do
      feed << nil
    end
    assert_equal '<feed/>', feed.to_s
  end
end
