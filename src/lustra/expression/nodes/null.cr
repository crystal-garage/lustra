require "./node"

# Render NULL !
class Lustra::Expression::Node::Null < Lustra::Expression::Node
  def initialize
  end

  def resolve : String
    "NULL"
  end
end
