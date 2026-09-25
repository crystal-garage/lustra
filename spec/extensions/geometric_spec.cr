require "../spec_helper"

describe "Lustra Geometric Extensions" do
  describe "Expression Engine Geometric Operations" do
    it "supports distance_to with literal and column arguments" do
      point = PG::Geo::Point.new(3.0, 4.0)

      Lustra::Expression.where { coordinates.distance_to(point) }.resolve
        .should eq %(("coordinates" <-> point(3.0,4.0)))
      Lustra::Expression.where { coordinates.distance_to(destination) }.resolve
        .should eq %(("coordinates" <-> "destination"))
    end

    it "supports within? with literal and column containers" do
      circle = PG::Geo::Circle.new(0.0, 0.0, 5.0)

      Lustra::Expression.where { coordinates.within?(circle) }.resolve
        .should eq %((circle(point(0.0,0.0),5.0) @> "coordinates"))
      Lustra::Expression.where { coordinates.within?(area) }.resolve
        .should eq %(("area" @> "coordinates"))

      query = Lustra::SQL.select("id")
        .from("(VALUES (1, point(0, 0)), (2, point(3, 4)), (3, point(6, 0))) AS locations(id, coordinates)")
        .where { coordinates.within?(circle) }.order_by(:id)
      query.pluck_col(:id).should eq([1, 2])
    end

    {% for predicate in [
                          {"within_distance?", "<=", [1, 2]},
                          {"within_radius?", "<=", [1, 2]},
                          {"nearest_to?", "<=", [1, 2]},
                          {"farther_than?", ">", [3]},
                          {"closer_than?", "<", [1]},
                        ] %}
      {% method, operator, expected = predicate[0], predicate[1], predicate[2] %}
      it "generates {{ method.id }} with literal and column arguments" do
        point = PG::Geo::Point.new(0.0, 0.0)

        Lustra::Expression.where { coordinates.{{ method.id }}(point, 5.0) }.resolve
          .should eq "((\"coordinates\" <-> point(0.0,0.0)) {{ operator.id }} 5.0)"
        Lustra::Expression.where { coordinates.{{ method.id }}(destination, max_distance) }.resolve
          .should eq "((\"coordinates\" <-> \"destination\") {{ operator.id }} \"max_distance\")"
      end

      it "handles points below, at, and above the distance boundary for {{ method.id }}" do
        point = PG::Geo::Point.new(0.0, 0.0)
        query = Lustra::SQL.select("id")
          .from("(VALUES (1, point(0, 0)), (2, point(3, 4)), (3, point(6, 0)), (4, NULL::point)) AS locations(id, coordinates)")
          .where { coordinates.{{ method.id }}(point, 5.0) }.order_by(:id)

        query.pluck_col(:id).should eq({{ expected }})
      end
    {% end %}

    it "supports geometric predicates between columns" do
      Lustra::Expression.where { area.contains?(coordinates) }.resolve
        .should eq %(("area" @> "coordinates"))
      Lustra::Expression.where { coordinates.contained_by?(area) }.resolve
        .should eq %(("area" @> "coordinates"))
      Lustra::Expression.where { area.overlaps?(other_area) }.resolve
        .should eq %(("area" && "other_area"))
      Lustra::Expression.where { path.intersects?(other_path) }.resolve
        .should eq %(("path" ?# "other_path"))
      Lustra::Expression.where { coordinates.left_of?(destination) }.resolve
        .should eq %(("coordinates" << "destination"))
      Lustra::Expression.where { coordinates.right_of?(destination) }.resolve
        .should eq %(("coordinates" >> "destination"))
      Lustra::Expression.where { coordinates.above?(destination) }.resolve
        .should eq %(("coordinates" |>> "destination"))
      Lustra::Expression.where { coordinates.below?(destination) }.resolve
        .should eq %(("coordinates" <<| "destination"))
      Lustra::Expression.where { coordinates.same_as?(destination) }.resolve
        .should eq %(("coordinates" ~= "destination"))
    end

    it "should generate correct distance queries" do
      point = PG::Geo::Point.new(3.0, 4.0)

      # Test distance_from method
      expression = Lustra::Expression.where { coordinates.distance_from(point) }
      expression.resolve.should eq("(\"coordinates\" <-> point(3.0,4.0))")
    end

    it "should generate correct containment queries" do
      point = PG::Geo::Point.new(1.0, 1.0)

      # Test contains? method
      expression = Lustra::Expression.where { search_area.contains?(point) }
      expression.resolve.should eq("(\"search_area\" @> point(1.0,1.0))")

      # Test contained_by? method (reverse containment)
      polygon = PG::Geo::Polygon.new([PG::Geo::Point.new(0.0, 0.0), PG::Geo::Point.new(2.0, 0.0), PG::Geo::Point.new(2.0, 2.0), PG::Geo::Point.new(0.0, 2.0)])
      expression = Lustra::Expression.where { coordinates.contained_by?(polygon) }
      expression.resolve.should eq("(polygon'((0.0,0.0),(2.0,0.0),(2.0,2.0),(0.0,2.0))' @> \"coordinates\")")
    end

    it "should generate correct overlap queries" do
      circle = PG::Geo::Circle.new(3.0, 4.0, 3.0)

      # Test overlaps? method
      expression = Lustra::Expression.where { area.overlaps?(circle) }
      expression.resolve.should eq("(\"area\" && circle(point(3.0,4.0),3.0))")
    end

    it "should generate correct intersection queries" do
      line = PG::Geo::Line.new(1.0, -1.0, 0.0) # Line equation: x - y = 0

      # Test intersects? method
      expression = Lustra::Expression.where { path.intersects?(line) }
      expression.resolve.should eq("(\"path\" ?# line'{1.0,-1.0,0.0}')")
    end

    it "should generate correct positioning queries" do
      point = PG::Geo::Point.new(5.0, 0.0)

      # Test left_of? method
      expression = Lustra::Expression.where { coordinates.left_of?(point) }
      expression.resolve.should eq("(\"coordinates\" << point(5.0,0.0))")

      # Test right_of? method
      expression = Lustra::Expression.where { coordinates.right_of?(point) }
      expression.resolve.should eq("(\"coordinates\" >> point(5.0,0.0))")

      # Test above? method
      expression = Lustra::Expression.where { coordinates.above?(point) }
      expression.resolve.should eq("(\"coordinates\" |>> point(5.0,0.0))")

      # Test below? method
      expression = Lustra::Expression.where { coordinates.below?(point) }
      expression.resolve.should eq("(\"coordinates\" <<| point(5.0,0.0))")

      # Test same_as? method
      expression = Lustra::Expression.where { coordinates.same_as?(point) }
      expression.resolve.should eq("(\"coordinates\" ~= point(5.0,0.0))")
    end

    it "should combine distance with comparison operators" do
      point = PG::Geo::Point.new(0.0, 0.0)
      max_distance = 1000.0

      # Test within_distance? method
      expression = Lustra::Expression.where { coordinates.within_distance?(point, max_distance) }
      expression.resolve.should eq("((\"coordinates\" <-> point(0.0,0.0)) <= 1000.0)")
    end
  end
end
