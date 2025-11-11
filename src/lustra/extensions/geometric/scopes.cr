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
    scope("nearest_to") { |point, max_results|
      order_by("coordinates <-> point(#{point.x},#{point.y})").limit(max_results)
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

  # Calculate Euclidean distance to another location using PostgreSQL's <-> operator.
  # Returns distance in coordinate system units:
  # - For lat/lng coordinates: distance in degrees (NOT geographic distance)
  # - For Cartesian coordinates: distance in whatever units your coordinate system uses
  # Note: This does NOT account for Earth's curvature. For real-world GPS distances,
  # consider using PostGIS geography types or apply geographic distance formulas.
  # Returns nil if either location has NULL coordinates or if the record is not found.
  def distance_to(other_location) : Float64?
    # Use raw SQL for precise distance calculation
    result = self.class.query
      .select("coordinates <-> point(#{other_location.coordinates.x},#{other_location.coordinates.y}) as distance")
      .where(id: self.id)
      .to_a(fetch_columns: true)
      .first?

    return nil unless result

    result["distance"].as(Float64)
  end

  def within_radius?(center_point, radius)
    distance_to_center = self.class.query
      .select("coordinates <-> point(#{center_point.x},#{center_point.y}) as distance")
      .where(id: self.id)
      .to_a(fetch_columns: true)
      .first?

    return false unless distance_to_center

    distance = distance_to_center["distance"].as(Float64)

    return false unless distance

    distance <= radius
  end

  def nearby_locations(radius = 1000.0, max_results = 10)
    self.class.query
      .where("coordinates <-> point(#{self.coordinates.x},#{self.coordinates.y}) <= ?", radius)
      .where("id != ?", self.id)
      .order_by("coordinates <-> point(#{self.coordinates.x},#{self.coordinates.y})")
      .limit(max_results)
  end

  def closest_to(target_point)
    self.class.query
      .where("id != ?", self.id)
      .order_by("coordinates <-> point(#{target_point.x},#{target_point.y})")
      .first?
  end

  def farthest_from(target_point)
    self.class.query
      .where("id != ?", self.id)
      .order_by("coordinates <-> point(#{target_point.x},#{target_point.y})", :desc)
      .first?
  end
end
