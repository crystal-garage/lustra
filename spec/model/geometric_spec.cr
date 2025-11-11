require "../spec_helper"
require "../data/example_models"
require "../../src/lustra/extensions/geometric/geometric"

module GeometricSpec
  describe "PostgreSQL Geometric Types Complete Test Suite" do
    it "creates and retrieves geometric records" do
      temporary do
        reinit_example_models

        # Test Point type
        point_location = Location.create!(
          name: "Point Location",
          coordinates: PG::Geo::Point.new(40.7128, -74.0060)
        )

        # Test Circle type
        circle_location = Location.create!(
          name: "Circle Location",
          coordinates: PG::Geo::Point.new(42.3601, -71.0589),
          coverage_area: PG::Geo::Circle.new(42.3601, -71.0589, 0.08)
        )

        # Test Polygon type
        polygon_location = Location.create!(
          name: "Polygon Location",
          coordinates: PG::Geo::Point.new(39.9526, -75.1652),
          service_boundary: PG::Geo::Polygon.new([
            PG::Geo::Point.new(39.9, -75.2),
            PG::Geo::Point.new(40.0, -75.2),
            PG::Geo::Point.new(40.0, -75.1),
            PG::Geo::Point.new(39.9, -75.1),
          ])
        )

        # Test Box type
        box_location = Location.create!(
          name: "Box Location",
          coordinates: PG::Geo::Point.new(34.0522, -118.2437),
          bounding_box: PG::Geo::Box.new(34.0, -118.3, 34.1, -118.2)
        )

        # Test retrieval and verification
        locations = Location.query.order_by(:name).to_a
        locations.size.should eq(4)

        # Verify Point
        point = locations.find { |l| l.name == "Point Location" }
        point.should_not be_nil
        point.not_nil!.coordinates.x.should be_close(40.7128, 0.001)
        point.not_nil!.coordinates.y.should be_close(-74.0060, 0.001)

        # Verify Circle
        circle = locations.find { |l| l.name == "Circle Location" }
        circle.should_not be_nil
        circle.not_nil!.coverage_area.should_not be_nil
        circle.not_nil!.coverage_area.not_nil!.radius.should be_close(0.08, 0.001)

        # Verify Polygon
        polygon = locations.find { |l| l.name == "Polygon Location" }
        polygon.should_not be_nil
        polygon.not_nil!.service_boundary.should_not be_nil
        polygon.not_nil!.service_boundary.not_nil!.points.size.should eq(4)

        # Verify Box
        box = locations.find { |l| l.name == "Box Location" }
        box.should_not be_nil
        box.not_nil!.bounding_box.should_not be_nil
        box_val = box.not_nil!.bounding_box.not_nil!
        box_val.x1.should be_close(34.0, 0.001)
        box_val.x2.should be_close(34.1, 0.001)
      end
    end

    it "validates geometric expression engine work correctly" do
      temporary do
        reinit_example_models

        Location.create!(
          name: "NYC Store",
          coordinates: PG::Geo::Point.new(40.7128, -74.0060),
          coverage_area: PG::Geo::Circle.new(40.7128, -74.0060, 0.1),
          service_boundary: PG::Geo::Polygon.new([
            PG::Geo::Point.new(40.7, -74.1),
            PG::Geo::Point.new(40.8, -74.1),
            PG::Geo::Point.new(40.8, -74.0),
            PG::Geo::Point.new(40.7, -74.0),
          ])
        )

        # Test variables
        target_point = PG::Geo::Point.new(40.713, -74.006)
        max_distance = 1000.0
        user_location = PG::Geo::Point.new(40.72, -74.01) # Inside NYC coverage area

        # Test: Individual geometric operations work
        distance_query = Location.query.where { coordinates.distance_from(target_point) <= max_distance }
        distance_query.to_sql.should contain("<-> point(40.713,-74.006)")
        distance_query.to_sql.should contain("<= 1000.0")
        distance_results = distance_query.to_a
        distance_results.size.should eq(1)

        # Test: Containment operations work
        containment_query = Location.query.where { coverage_area.contains?(user_location) }
        containment_query.to_sql.should contain("@> point(40.72,-74.01)")
        containment_results = containment_query.to_a
        containment_results.size.should eq(1)

        # Test: Complex combined query
        # Note: Using points that are actually within the geometric shapes
        point_in_polygon = PG::Geo::Point.new(40.75, -74.05) # Inside the service boundary

        combined_query = Location.query.where {
          (coordinates.distance_from(target_point) <= max_distance) &
            (coverage_area.contains?(user_location)) &
            (service_boundary.contains?(point_in_polygon))
        }

        # Verify the SQL is correctly generated with proper operators and PostgreSQL format
        sql = combined_query.to_sql
        sql.should contain("<-> point(40.713,-74.006)")
        sql.should contain("@> point(40.72,-74.01)")
        sql.should contain("@> point(40.75,-74.05)")
        sql.should contain("AND") # Verify the query executes successfully
        combined_results = combined_query.to_a
        combined_results.size.should eq(1)
        combined_results.first.name.should eq("NYC Store")
      end
    end
  end
end
