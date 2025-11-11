require "./geometric"

# Define a __distance (<->)__ operation between geometric objects
class Lustra::Expression::Node::Geometric::Distance < Lustra::Expression::Node
  getter left : Node
  getter right : Node

  def initialize(@left, @right)
  end

  def resolve : String
    {"(", @left.resolve, " <-> ", @right.resolve, ")"}.join
  end
end

# Define a __containment (@>)__ operation between geometric objects
class Lustra::Expression::Node::Geometric::Contains < Lustra::Expression::Node
  getter container : Node
  getter contained : Node

  def initialize(@container, @contained)
  end

  def resolve : String
    {"(", @container.resolve, " @> ", @contained.resolve, ")"}.join
  end
end

# Define a __overlap (&&)__ operation between geometric objects
class Lustra::Expression::Node::Geometric::Overlaps < Lustra::Expression::Node
  getter left : Node
  getter right : Node

  def initialize(@left, @right)
  end

  def resolve : String
    {"(", @left.resolve, " && ", @right.resolve, ")"}.join
  end
end

# Define a __intersection (?#)__ operation between geometric objects
class Lustra::Expression::Node::Geometric::Intersects < Lustra::Expression::Node
  getter left : Node
  getter right : Node

  def initialize(@left, @right)
  end

  def resolve : String
    {"(", @left.resolve, " ?# ", @right.resolve, ")"}.join
  end
end

# Define a __left of (<<)__ operation between geometric objects
class Lustra::Expression::Node::Geometric::LeftOf < Lustra::Expression::Node
  getter left : Node
  getter right : Node

  def initialize(@left, @right)
  end

  def resolve : String
    {"(", @left.resolve, " << ", @right.resolve, ")"}.join
  end
end

# Define a __right of (>>)__ operation between geometric objects
class Lustra::Expression::Node::Geometric::RightOf < Lustra::Expression::Node
  getter left : Node
  getter right : Node

  def initialize(@left, @right)
  end

  def resolve : String
    {"(", @left.resolve, " >> ", @right.resolve, ")"}.join
  end
end

# Define a __above (|>>)__ operation between geometric objects
class Lustra::Expression::Node::Geometric::Above < Lustra::Expression::Node
  getter left : Node
  getter right : Node

  def initialize(@left, @right)
  end

  def resolve : String
    {"(", @left.resolve, " |>> ", @right.resolve, ")"}.join
  end
end

# Define a __below (<<|)__ operation between geometric objects
class Lustra::Expression::Node::Geometric::Below < Lustra::Expression::Node
  getter left : Node
  getter right : Node

  def initialize(@left, @right)
  end

  def resolve : String
    {"(", @left.resolve, " <<| ", @right.resolve, ")"}.join
  end
end

# Define a __same as (~=)__ operation between geometric objects
class Lustra::Expression::Node::Geometric::SameAs < Lustra::Expression::Node
  getter left : Node
  getter right : Node

  def initialize(@left, @right)
  end

  def resolve : String
    {"(", @left.resolve, " ~= ", @right.resolve, ")"}.join
  end
end
