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
end
