require "./node"

# This node manage the rendering of a raw SQL fragment.
class Lustra::Expression::Node::Raw < Lustra::Expression::Node
  def initialize(@raw : String); end

  def resolve : String
    @raw
  end
end
