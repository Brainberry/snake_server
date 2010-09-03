require 'nokogiri'
require File.expand_path(File.dirname(__FILE__) + '/blank')
require File.expand_path(File.dirname(__FILE__) + '/xml_mini')

class Hash
  XML_TYPE_NAMES = {
    "Symbol"     => "symbol",
    "Fixnum"     => "integer",
    "Bignum"     => "integer",
    "BigDecimal" => "decimal",
    "Float"      => "float",
    "TrueClass"  => "boolean",
    "FalseClass" => "boolean",
    "Date"       => "date",
    "DateTime"   => "datetime",
    "Time"       => "datetime",
    "ActiveSupport::TimeWithZone" => "datetime"
  } unless defined?(XML_TYPE_NAMES)

  XML_FORMATTING = {
    "symbol"   => Proc.new { |symbol| symbol.to_s },
    "date"     => Proc.new { |date| date.to_s(:db) },
    "datetime" => Proc.new { |time| time.xmlschema },
    "binary"   => Proc.new { |binary| ActiveSupport::Base64.encode64(binary) },
    "yaml"     => Proc.new { |yaml| yaml.to_yaml }
  } unless defined?(XML_FORMATTING)
  
  # TODO: use Time.xmlschema instead of Time.parse;
  #       use regexp instead of Date.parse
  unless defined?(XML_PARSING)
    XML_PARSING = {
      "symbol"       => Proc.new  { |symbol|  symbol.to_sym },
      "date"         => Proc.new  { |date|    ::Date.parse(date) },
      "datetime"     => Proc.new  { |time|    ::Time.parse(time).utc rescue ::DateTime.parse(time).utc },
      "integer"      => Proc.new  { |integer| integer.to_i },
      "float"        => Proc.new  { |float|   float.to_f },
      "decimal"      => Proc.new  { |number|  BigDecimal(number) },
      "boolean"      => Proc.new  { |boolean| %w(1 true).include?(boolean.strip) },
      "string"       => Proc.new  { |string|  string.to_s },
      "yaml"         => Proc.new  { |yaml|    YAML::load(yaml) rescue yaml },
      "base64Binary" => Proc.new  { |bin|     ActiveSupport::Base64.decode64(bin) },
      "file"         => Proc.new do |file, entity|
        f = StringIO.new(ActiveSupport::Base64.decode64(file))
        f.extend(FileLike)
        f.original_filename = entity['name']
        f.content_type = entity['content_type']
        f
      end
    }

    XML_PARSING.update(
      "double"   => XML_PARSING["float"],
      "dateTime" => XML_PARSING["datetime"]
    )
  end
  
  def to_xml(options = {})
    #options[:indent] ||= 2
    options[:encoding] ||= 'UTF-8'
    
    root = options.delete(:root) || "params"
    @objects = self
    
    builder = Nokogiri::XML::Builder.new(options) do |xml|
      xml.send(root) {
        self.class.convert_to_xml(self, xml, options)
      }
    end
    
    builder.to_xml
  end
  
  # Return a new hash with all keys converted to strings.
  def stringify_keys
    inject({}) do |options, (key, value)|
      options[key.to_s] = value
      options
    end
  end

  # Destructively convert all keys to strings.
  def stringify_keys!
    keys.each do |key|
      self[key.to_s] = delete(key)
    end
    self
  end
  
  # Return a new hash with all keys converted to symbols.
  def symbolize_keys
    inject({}) do |options, (key, value)|
      options[(key.to_sym rescue key) || key] = value
      options
    end
  end

  # Destructively convert all keys to symbols.
  def symbolize_keys!
    self.replace(self.symbolize_keys)
  end
  
  class << self
    def from_xml(xml, options = {})
      typecast_xml_value(unrename_keys(Snake::XmlMini.parse(xml)))    
    end
      
    def convert_to_xml(hash, xml, options = {})
      hash.each do |key, value|
        xml_key = key.to_sym
        xml_key = "#{key}_" if [:id, :class, :type].include?(xml_key)
        
        case value
          when ::Hash
            xml.send(xml_key) do |ch|
              convert_to_xml(value, ch)
            end
          else
            type_name = XML_TYPE_NAMES[value.class.name]

            attributes = options[:skip_types] || value.nil? || type_name.nil? ? { } : { :type => type_name }
            attributes[:nil] = true if value.nil?

            xml.send(xml_key,
              XML_FORMATTING[type_name] ? XML_FORMATTING[type_name].call(value) : value,
              attributes
            )
        end
      end
    end
    
    private
    
      def typecast_xml_value(value)
        case value.class.to_s
          when 'Hash'
            if value['type'] == 'array'
              child_key, entries = value.detect { |k,v| k != 'type' }   # child_key is throwaway
              if entries.nil? || (c = value['__content__'] && c.blank?)
                []
              else
                case entries.class.to_s   # something weird with classes not matching here.  maybe singleton methods breaking is_a?
                when "Array"
                  entries.collect { |v| typecast_xml_value(v) }
                when "Hash"
                  [typecast_xml_value(entries)]
                else
                  raise "can't typecast #{entries.inspect}"
                end
              end
            elsif value.has_key?("__content__")
              content = value["__content__"]
              if parser = XML_PARSING[value["type"]]
                if parser.arity == 2
                  XML_PARSING[value["type"]].call(content, value)
                else
                  XML_PARSING[value["type"]].call(content)
                end
              else
                content
              end
            elsif value['type'] == 'string' && value['nil'] != 'true'
              ""
            # blank or nil parsed values are represented by nil
            elsif value.blank? || value['nil'] == 'true'
              nil
            # If the type is the only element which makes it then 
            # this still makes the value nil, except if type is
            # a XML node(where type['value'] is a Hash)
            elsif value['type'] && value.size == 1 && !value['type'].is_a?(::Hash)
              nil
            else
              xml_value = value.inject({}) do |h,(k,v)|
                h[k] = typecast_xml_value(v)
                h
              end
              
              # Turn { :files => { :file => #<StringIO> } into { :files => #<StringIO> } so it is compatible with
              # how multipart uploaded files from HTML appear
              xml_value["file"].is_a?(StringIO) ? xml_value["file"] : xml_value
            end
          when 'Array'
            value.map! { |i| typecast_xml_value(i) }
            case value.length
              when 0 then nil
              when 1 then value.first
              else value
            end
          when 'String'
            value
          else
            raise "can't typecast #{value.class.name} - #{value.inspect}"
        end
      end

      def unrename_keys(params)
        case params.class.to_s
          when "Hash"
            params.inject({}) do |h,(k,v)|
              h[k.to_s.tr("-", "_")] = unrename_keys(v)
              h
            end
          when "Array"
            params.map { |v| unrename_keys(v) }
          else
            params
        end
      end
  end
end
