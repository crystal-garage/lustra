require "./base"

module Lustra::Model::Converter::JSON::AnyConverter
  def self.to_column(x) : ::JSON::Any?
    case x
    when Nil
      nil
    when ::JSON::Any
      x
    when ::JSON::PullParser
      ::JSON::Any.new(x)
    else
      ::JSON.parse(x.to_s)
    end
  end

  def self.to_db(x : ::JSON::Any?)
    x.to_json
  end
end

Lustra::Model::Converter.add_converter("JSON::Any", Lustra::Model::Converter::JSON::AnyConverter)

module Lustra
  # Register a type to allow use in Lustra column system.
  # Type must include JSON::Serializable.
  # [More info about how to use JSON::Serializable it can be found here](https://crystal-lang.org/api/latest/JSON/Serializable.html)
  #
  # ```
  # Lustra.json_serializable_converter(MyJsonType)
  #
  # # ...
  #
  # class YourModel
  #   include Lustra::Model
  #   # ...
  #   column my_column : MyJsonType # jsonb (recommended), json or string column in postgresql.
  # end
  # ```
  macro json_serializable_converter(type)
    {% type = type.resolve %}
    module ::Lustra::Model::Converter::{{ type }}Converter
      def self.to_column(x) : ::{{ type }}?
        case x
        when ::{{ type }}
          x
        when String
          ::{{ type }}.new(::JSON::PullParser.new(x))
        when ::JSON::PullParser
          ::{{ type }}.new(x)
        when ::JSON::Any
          ::{{ type }}.new(::JSON::PullParser.new(x.to_json))
        else
          raise "Cannot convert to {{ type }} from #{x.class}"
        end
      end

      def self.to_db(x : ::{{ type }}?)
        x ? x.to_json : nil
      end
    end

    ::Lustra::Model::Converter.add_converter({{ "#{type}" }}, ::Lustra::Model::Converter::{{ type }}Converter)
  end
end
