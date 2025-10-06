require "./jsonb"

class Lustra::Expression::Node::JSONB::Field < Lustra::Expression::Node
  include Lustra::SQL::JSONB

  getter field : Node
  getter key : String
  getter cast : String?

  def initialize(@field, @key, @cast = nil)
  end

  def resolve : String
    jsonb_resolve(@field.resolve, jsonb_k2a(key), @cast)
  end

  def cast(@cast)
    self
  end

  def ==(value : Lustra::Expression::Node)
    super(value) # << Keep same for node which are not literal value
  end

  def ==(value : _) # << For other type, literalize and use smart JSONB equality
    if @cast
      super(value)
    else
      Lustra::Expression::Node::JSONB::Equality.new(field.resolve, jsonb_k2h(key, value))
    end
  end

  def contains?(expression : Lustra::Expression::Node)
    Lustra::Expression::Node::JSONB::ArrayContains.new(resolve, expression.resolve)
  end

  def contains?(expression)
    Lustra::Expression::Node::JSONB::ArrayContains.new(resolve, Lustra::Expression[expression])
  end
end

# Define a __value match? (@>)__ operation between a jsonb column and a json hash
class Lustra::Expression::Node::JSONB::Equality < Lustra::Expression::Node
  include Lustra::SQL::JSONB

  getter jsonb_field : String
  getter value : JSONBHash

  def initialize(@jsonb_field, @value)
  end

  def resolve : String
    {@jsonb_field, Lustra::Expression[@value.to_json]}.join(" @> ")
  end
end

# Define a __array contains? (?)__ operation between a jsonb column and a json hash
class Lustra::Expression::Node::JSONB::ArrayContains < Lustra::Expression::Node
  getter jsonb_field : String
  getter value : String

  def initialize(@jsonb_field, @value)
  end

  def resolve : String
    {@jsonb_field, @value}.join(" ? ")
  end
end
