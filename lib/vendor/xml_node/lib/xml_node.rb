require 'rexml/document'

class Object
  def to_xml_value
    to_s
  end
end

class NilClass
  def to_xml_value
    nil
  end
end

class TrueClass
  def to_xml_value
    to_s
  end
end 

class FalseClass
  def to_xml_value
    to_s
  end
end 

class Time
  def to_xml_value
    self.xmlschema
  end
end

class DateTime
  def to_xml_value
    self.xmlschema
  end
end

class Date
  def to_xml_value
    self.to_time.xmlschema
  end
end

class REXML::Element
  def to_xml_element
    self
  end
end

class XmlNode
  attr_accessor :child_nodes
  attr_reader :element 
  
  class List
    include Enumerable
    
    def initialize(parent)
      @parent = parent
      @children = {}
    end

    def [](value)
      node_for @parent.element.elements[value]
    end
    
    def []=(value, key)
      @parent.element.elements[value.to_s] = key.to_xml_element
    end
    
    def each(&block)
      @parent.element.each_element { |e| yield node_for(e) }
    end
    
    private
    
    def node_for(element)
      @parent.child_nodes[element] ||= XmlNode.new(element)
    end
  end
  
  # Allows for very pretty xml generation akin to xml builder.
  #
  # Example:
  # 
  #   # Create an atom like document
  #   doc = Document.new 
  #   doc.root = XmlNode.new 'feed' do |feed|
  #     
  #     feed << XmlNode.new('id', 'tag:atom.com,2007:1')
  #     feed << XmlNode.new('title', 'Atom test feed')
  #     feed << XmlNode.new('author') do |author|
  #       author << XmlNode.new("name", "tobi")
  #       author << XmlNode.new("email", "tobi@gmail.com")
  #     end
  #     
  #     feed << XmlNode.new('entry') do |entry|
  #       entry << XmlNode.new('title', 'First post')
  #       entry << XmlNode.new('summary', 'Lorem ipsum', :type => 'xhtml')
  #       entry << XmlNode.new('created_at', Time.now)
  #     end
  #     
  #     feed << XmlNode.new('dc:published', Time.now)
  #   end
  #
  def initialize(node, *args)
    @element = if node.is_a?(REXML::Element)
      node
    else      
      REXML::Element.new(node)    
    end
    
    @child_nodes = {}
    
    if attributes = args.last.is_a?(Hash) ? args.pop : nil
      attributes.each { |k,v| @element.add_attribute(k.to_s, v.to_xml_value) }
    end
    
    if !args[0].nil?
      @element.text = args[0].to_xml_value
    end

    if block_given?    
      yield self 
    end
  end

  def self.parse(xml)
    self.new(REXML::Document.new(xml).root)
  end
  
  def children
    XmlNode::List.new(self)
  end
  
  def []=(key, value)
    @element.attributes[key.to_s] =  value.to_xml_value
  end
  
  def [](key)
    @element.attributes[key]
  end
  
  # Add a namespace to the node
  # Example
  #
  #   node.namespace 'http://www.w3.org/2005/Atom'
  #   node.namespace :opensearch, 'http://a9.com/-/spec/opensearch/1.1/'
  #
  def namespace(*args) 
    args[0] = args[0].to_s if args[0].is_a?(Symbol)
    @element.add_namespace(*args)
  end
  
  def cdata=(value)
    new_cdata = REXML::CData.new( value )
    @element.children.each do |c|
      if c.is_a?(REXML::CData)
        return @element.replace_child(c,new_cdata)
      end
    end    
    @element << new_cdata
  rescue RuntimeError => e            
    @element << REXML::Text.new(e.message)
  end
  
  def cdata
    @element.cdatas.first.to_s
  end
  
  def name
    @element.name
  end
  
  def text=(value)
    @element.text = REXML::Text.new( value )    
  end
  
  def text
    @element.text
  end
  
  def find(scope, xpath)    
    case scope 
    when :first
      elem = @element.elements[xpath]
      elem.nil? ? nil : child_nodes[elem] ||= XmlNode.new(elem)
    when :all 
      @element.elements.to_a(xpath).collect { |e| child_nodes[e] ||= XmlNode.new(e) }    
    end
  end
  
  def <<(elem)    
    case elem
    when nil then return
    when Array 
      elem.each { |e| @element << e.to_xml_element }
    else
      @element << elem.to_xml_element
    end
  end
    
  def to_xml_element
    @element
  end
  
  def to_s
    @element.to_s
  end
  
  # Use to get pretty formatted xml including DECL
  # instructions
  def to_xml
    xml = []
    document = REXML::Document.new
    document << REXML::XMLDecl.new('1.0')
    document << @element
    document.write( xml, 0)
    xml.join
  end
  
end