require "./node"

# A node managing the rendering of `(var NOT BETWEEN a AND b)`
# expressions.
class Lustra::Expression::Node::NotBetween < Lustra::Expression::Node
  alias BetweenType = Int32 | Int64 | Float32 | Float64 | String | Time | Node

  def initialize(@target : Node, @starts : BetweenType, @ends : BetweenType)
  end

  def resolve : String
    {
      "(",
      @target.resolve,
      " NOT BETWEEN ",
      Lustra::Expression[@starts],
      " AND ",
      Lustra::Expression[@ends],
      ")",
    }.join
  end
end
