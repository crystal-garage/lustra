require "./node"

# A node managing the rendering a range in Postgres.
#
# Example:
#
# ```
# value.in?(1..5)
# ```
#
# will render:
#
# ```
# value >= 1 AND value <= 5
# ```
#
# Supports beginless and endless ranges:
#
# ```
# value.in?(..10)  # value <= 10
# value.in?(1..)   # value >= 1
# value.in?(...10) # value < 10
# ```
#
# Inclusion and exclusion of the last number of the range is featured
#
class Lustra::Expression::Node::InRange < Lustra::Expression::Node
  def initialize(@target : Node, @range : Range(String?, String?), @exclusive = false); end

  def resolve : String
    rt = @target.resolve
    range_begin = @range.begin
    range_end = @range.end

    # Handle beginless range (..10 or ...10)
    if range_begin.nil? && range_end
      op = @exclusive ? " < " : " <= "
      return {"(", rt, op, range_end, ")"}.join
    end

    # Handle endless range (10..)
    if range_end.nil? && range_begin
      return {"(", rt, " >= ", range_begin, ")"}.join
    end

    # Handle normal range (10..20)
    if range_begin && range_end
      final_op = @exclusive ? " < " : " <= "
      return {"(", rt, " >= ", range_begin, " AND ", rt, final_op, range_end, ")"}.join
    end

    # Should not reach here, but handle edge case of (nil..nil)
    raise "Invalid range: both begin and end cannot be nil"
  end
end
