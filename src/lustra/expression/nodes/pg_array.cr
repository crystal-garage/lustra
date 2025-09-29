require "./node"

# A node managing PG structure `array[args...]`
# Named PGArray instead of Array to avoid issue with naming
class Lustra::Expression::Node::PGArray(T) < Lustra::Expression::Node
  @arr : Array(T)

  def initialize(@arr : Array(T))
  end

  def resolve : String
    {"array[", Lustra::Expression[@arr].join(", "), "]"}.join
  end
end
