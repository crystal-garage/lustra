require "./node"

# A node managing the unary `NOT` operator.
class Lustra::Expression::Node::Not < Lustra::Expression::Node
  def initialize(@a : Node); end

  def resolve : String
    {"NOT ", @a.resolve}.join
  end
end
