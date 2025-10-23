require "pg"
require "json"

module Lustra::Model::Converter
  abstract class Base
  end

  CONVERTERS = {} of String => Base.class

  macro add_converter(name, klass)
    {% CONVERTERS[name] = klass %}
  end

  macro to_column(name, value)
    {% if !name.is_a?(StringLiteral) %}
      {% name = "#{name}" %}
    {% end %}

    {% if CONVERTERS[name] == nil %}
      {% raise "Unknown converter: #{name}" %}
    {% end %}

    {{ CONVERTERS[name] }}.to_column({{ value }})
  end

  macro to_db(name, value)
    {% if !name.is_a?(StringLiteral) %}
      {% name = "#{name.resolve}" %}
    {% end %}

    {% if CONVERTERS[name] == nil %}
      {% raise "Unknown converter: #{name}" %}
    {% end %}

    {{ CONVERTERS[name] }}.to_db({{ value }})
  end
end
