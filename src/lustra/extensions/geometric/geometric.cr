# ## Geometric Integration with Lustra
#
# Lustra supports natively PostgreSQL geometric columns including:
# Point, Circle, Polygon, Box, Line, Path, and LineSegment
#
# Functions can be used calling or including Lustra::SQL::Geometric methods as helper methods:
#
# ```
# class MyClass
#   include Lustra::SQL::Geometric
#
#   def create_sql_with_geometric
#     Lustra::SQL.select.where(geo_distance("coordinates", "center_point"))
#     # ^-- operator `<->`, returns distance between two points
#   end
# end
# ```
#
# Moreover, geometric operations are directly integrated into the Expression Engine.
# For that, just call geometric methods after a variable:
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

require "./expression"
require "./node"
require "./scopes"
require "./converters"

module Lustra::SQL::Geometric
  extend self

  # Distance operations using PostgreSQL <-> operator
  def geo_distance(left_field, right_field)
    {left_field, right_field}.join(" <-> ")
  end

  # Containment operations using @> operator
  def geo_contains(container_field, contained_field)
    {container_field, contained_field}.join(" @> ")
  end

  # Overlap operations using && operator
  def geo_overlaps(left_field, right_field)
    {left_field, right_field}.join(" && ")
  end

  # Intersection operations using ?# operator
  def geo_intersects(left_field, right_field)
    {left_field, right_field}.join(" ?# ")
  end

  # Left positioning using << operator
  def geo_left_of(left_field, right_field)
    {left_field, right_field}.join(" << ")
  end

  # Right positioning using >> operator
  def geo_right_of(left_field, right_field)
    {left_field, right_field}.join(" >> ")
  end

  # Above positioning using |>> operator
  def geo_above(left_field, right_field)
    {left_field, right_field}.join(" |>> ")
  end

  # Below positioning using <<| operator
  def geo_below(left_field, right_field)
    {left_field, right_field}.join(" <<| ")
  end

  # Same as operator using ~= operator
  def geo_same_as(left_field, right_field)
    {left_field, right_field}.join(" ~= ")
  end
end

class Lustra::Expression::Node
  include Lustra::Expression::Geometric::Node
end
