module Lustra::Expression::Geometric::Node
  # Distance operations
  def distance_from(other)
    other = Lustra::Expression::Node::Literal.new(other) unless other.is_a?(Lustra::Expression::Node)
    Lustra::Expression::Node::Geometric::Distance.new(self, other)
  end

  # Alias for distance_from
  def distance_to(other)
    distance_from(other)
  end

  # Containment operations
  def contains?(other)
    other = Lustra::Expression::Node::Literal.new(other) unless other.is_a?(Lustra::Expression::Node)
    Lustra::Expression::Node::Geometric::Contains.new(self, other)
  end

  def contained_by?(other)
    other = Lustra::Expression::Node::Literal.new(other) unless other.is_a?(Lustra::Expression::Node)
    Lustra::Expression::Node::Geometric::Contains.new(other, self)
  end

  def within?(other)
    contained_by?(other)
  end

  # Overlap operations
  def overlaps?(other)
    other = Lustra::Expression::Node::Literal.new(other) unless other.is_a?(Lustra::Expression::Node)
    Lustra::Expression::Node::Geometric::Overlaps.new(self, other)
  end

  # Intersection operations
  def intersects?(other)
    other = Lustra::Expression::Node::Literal.new(other) unless other.is_a?(Lustra::Expression::Node)
    Lustra::Expression::Node::Geometric::Intersects.new(self, other)
  end

  # Positioning operations
  def left_of?(other)
    other = Lustra::Expression::Node::Literal.new(other) unless other.is_a?(Lustra::Expression::Node)
    Lustra::Expression::Node::Geometric::LeftOf.new(self, other)
  end

  def right_of?(other)
    other = Lustra::Expression::Node::Literal.new(other) unless other.is_a?(Lustra::Expression::Node)
    Lustra::Expression::Node::Geometric::RightOf.new(self, other)
  end

  def above?(other)
    other = Lustra::Expression::Node::Literal.new(other) unless other.is_a?(Lustra::Expression::Node)
    Lustra::Expression::Node::Geometric::Above.new(self, other)
  end

  def below?(other)
    other = Lustra::Expression::Node::Literal.new(other) unless other.is_a?(Lustra::Expression::Node)
    Lustra::Expression::Node::Geometric::Below.new(self, other)
  end

  def same_as?(other)
    other = Lustra::Expression::Node::Literal.new(other) unless other.is_a?(Lustra::Expression::Node)
    Lustra::Expression::Node::Geometric::SameAs.new(self, other)
  end

  # Proximity operations (combining distance with comparison)
  def within_distance?(other, distance)
    distance_from(other) <= distance
  end

  def within_radius?(center, radius)
    distance_from(center) <= radius
  end

  def nearest_to?(other, max_distance)
    distance_from(other) <= max_distance
  end

  def farther_than?(other, min_distance)
    distance_from(other) > min_distance
  end

  def closer_than?(other, max_distance)
    distance_from(other) < max_distance
  end
end
