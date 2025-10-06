require "./base"

module Lustra::Model::Factory
  class PolymorphicFactory(T)
    include Base
    property type_field : String = ""
    property self_class : String = ""

    def initialize(@type_field, @self_class)
    end

    def build(h : Hash(String, ::Lustra::SQL::Any),
              cache : Lustra::Model::QueryCache? = nil,
              persisted : Bool = false,
              fetch_columns : Bool = false) : Lustra::Model
      v = h[@type_field]

      case v
      when String
        if v == T.name
          {% if T.abstract? %}
            raise "Cannot instantiate #{@type_field} because it is abstract class"
          {% else %}
            T.new(v, h, cache, persisted, fetch_columns).as(Lustra::Model)
          {% end %}
        else
          Lustra::Model::Factory.build(v, h, cache, persisted, fetch_columns).as(Lustra::Model)
        end
      when Nil
        raise Lustra::ErrorMessages.polymorphic_nil(@type_field)
      else
        raise Lustra::ErrorMessages.polymorphic_nil(@type_field)
      end
    end
  end
end
