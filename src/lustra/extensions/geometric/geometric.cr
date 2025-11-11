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
require "./migration"
require "./converters"

# Implement to_sql methods for PostgreSQL geometric types
# This allows them to be properly converted to PostgreSQL format when used as parameters
# in the expression engine. We return UnsafeSql to avoid automatic quoting.

struct PG::Geo::Point
  def to_sql
    Lustra::Expression::UnsafeSql.new("point(#{x},#{y})")
  end
end

struct PG::Geo::Circle
  def to_sql
    Lustra::Expression::UnsafeSql.new("circle(point(#{x},#{y}),#{radius})")
  end
end

struct PG::Geo::Polygon
  def to_sql
    points_str = points.map { |p| "(#{p.x},#{p.y})" }.join(",")
    Lustra::Expression::UnsafeSql.new("polygon'(#{points_str})'")
  end
end

struct PG::Geo::Box
  def to_sql
    Lustra::Expression::UnsafeSql.new("box(point(#{x1},#{y1}),point(#{x2},#{y2}))")
  end
end

struct PG::Geo::Line
  def to_sql
    Lustra::Expression::UnsafeSql.new("line'{#{a},#{b},#{c}}'")
  end
end

struct PG::Geo::Path
  def to_sql
    points_str = points.map { |p| "(#{p.x},#{p.y})" }.join(",")
    if closed?
      Lustra::Expression::UnsafeSql.new("path'((#{points_str}))'")
    else
      Lustra::Expression::UnsafeSql.new("path'[(#{points_str})]'")
    end
  end
end

struct PG::Geo::LineSegment
  def to_sql
    Lustra::Expression::UnsafeSql.new("lseg(point(#{x1},#{y1}),point(#{x2},#{y2}))")
  end
end

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
