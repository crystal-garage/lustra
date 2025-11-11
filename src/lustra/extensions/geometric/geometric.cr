# ## Geometric Integration with Lustra
#
# Lustra supports natively PostgreSQL geometric columns including:
# Point, Circle, Polygon, Box, Line, Path, and LineSegment
#
# Geometric operations are directly integrated into the Expression Engine.
# Just call geometric methods after a variable:
#
# ### Filter by geometric operations
#
# ```
# Location.query.where { coordinates.distance_from(target_point) <= max_distance }
# # ^-- Will produce optimized geometric query:
# # WHERE coordinates <-> target_point <= max_distance
#
# Location.query.where { search_area.contains?(user_location) }
# # ^-- Will produce containment query:
# # WHERE search_area @> user_location
# ```

require "./*"

class Lustra::Expression::Node
  include Lustra::Expression::Geometric::Node
end
