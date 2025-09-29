require "./node"

# Management of rendering of literal values.
class Lustra::Expression::Node::Literal < Lustra::Expression::Node
  getter value : AvailableLiteral

  def initialize(value)
    if value.is_a?(AvailableLiteral)
      @value = value
    elsif value.responds_to?(:to_sql)
      @value = value.to_sql
    else
      @value = value.to_s
    end
  end

  def resolve : String
    Lustra::Expression[@value]
  end
end
