require "./node"

# A node managing the rendering of `(var BETWEEN a AND b)`
# expressions.
class Lustra::Expression::Node::Between < Lustra::Expression::Node
  alias BetweenType = Int32 | Int64 | Float32 | Float64 | String | Time | Node

  def initialize(@target : Node, @starts : BetweenType, @ends : BetweenType)
  end

  def resolve : String
    {"(",
     @target.resolve,
     " BETWEEN ",
     Lustra::Expression.safe_literal(@starts),
     " AND ",
     Lustra::Expression.safe_literal(@ends),
     ")"}.join
  end
end
