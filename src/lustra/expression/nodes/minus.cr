require "./node"

# A node managing the unary `-` operator.
class Lustra::Expression::Node::Minus < Lustra::Expression::Node
  def initialize(@a : Node); end

  def resolve : String
    {"-", @a.resolve}.join
  end
end
