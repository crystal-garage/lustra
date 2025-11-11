module Lustra::Model::GeometricScopes
  macro included
    # Scope for finding records within a certain distance of a point
    scope("within_distance") { |point, distance|
      where { coordinates.distance_from(point) <= distance }
    }

    # Scope for finding records within a bounding box/polygon
    scope("within_bounds") { |boundary|
      where { coordinates.contained_by?(boundary) }
    }

    # Scope for finding records that overlap with a geometric shape
    scope("overlapping") { |shape|
      where { coordinates.overlaps?(shape) }
    }

    # Scope for finding nearest records to a point, ordered by distance
    scope("nearest_to") { |point, limit|
      order("coordinates <-> ?", point).limit(limit)
    }

    # Scope for finding records to the left of a reference object
    scope("left_of") { |reference|
      where { coordinates.left_of?(reference) }
    }

    # Scope for finding records to the right of a reference object
    scope("right_of") { |reference|
      where { coordinates.right_of?(reference) }
    }

    # Scope for finding records above a reference object
    scope("above") { |reference|
      where { coordinates.above?(reference) }
    }

    # Scope for finding records below a reference object
    scope("below") { |reference|
      where { coordinates.below?(reference) }
    }

    # Scope for finding records that intersect with a shape
    scope("intersecting") { |shape|
      where { coordinates.intersects?(shape) }
    }

    # Scope for finding records within a circular area
    scope("within_circle") { |center, radius|
      where { coordinates.within_distance?(center, radius) }
    }
  end

  # Instance methods for geometric operations
  def distance_to(other_location)
    # Use raw SQL for precise distance calculation
    self.class.query
      .select("coordinates <-> ? as distance", other_location.coordinates)
      .where(id: self.id)
      .first!["distance"].as(Float64)
  end

  def within_radius?(center_point, radius)
    distance_to_center = self.class.query
      .select("coordinates <-> ? as distance", center_point)
      .where(id: self.id)
      .first!["distance"].as(Float64)

    distance_to_center <= radius
  end

  def nearby_locations(radius = 1000.0, limit = 10)
    self.class.query
      .where { coordinates.distance_from(self.coordinates) <= radius }
      .where { id != self.id }
      .order("coordinates <-> ?", self.coordinates)
      .limit(limit)
  end

  def closest_to(target_point)
    self.class.query
      .where { id != self.id }
      .order("coordinates <-> ?", target_point)
      .first?
  end

  def farthest_from(target_point)
    self.class.query
      .where { id != self.id }
      .order("coordinates <-> ? DESC", target_point)
      .first?
  end
end
