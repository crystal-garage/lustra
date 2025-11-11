require "../spec_helper"
require "../data/example_models"

module GeometricInstanceMethodsSpec
  describe "Geometric Instance Methods" do
    it "tests distance_to instance method" do
      temporary do
        reinit_example_models

        location1 = Location.create!(
          name: "Location 1",
          coordinates: PG::Geo::Point.new(40.0, -74.0)
        )

        location2 = Location.create!(
          name: "Location 2",
          coordinates: PG::Geo::Point.new(40.01, -74.01)
        )

        # Test distance_to method
        distance = location1.distance_to(location2)

        distance.should_not be_nil
        distance = distance.not_nil!
        distance.should be_a(Float64)
        distance.should be > 0.0
        distance.should be < 1.0 # Should be less than 1 degree
      end
    end

    it "tests within_radius? instance method" do
      temporary do
        reinit_example_models

        location = Location.create!(
          name: "Test Location",
          coordinates: PG::Geo::Point.new(40.0, -74.0)
        )

        # Test points at different distances
        close_point = PG::Geo::Point.new(40.001, -74.001) # Very close
        far_point = PG::Geo::Point.new(41.0, -75.0)       # Far away

        # Test within_radius? method
        location.within_radius?(close_point, 0.1).should be_true
        location.within_radius?(far_point, 0.1).should be_false
        location.within_radius?(far_point, 2.0).should be_true # Large radius should include far point
      end
    end

    it "tests nearby_locations instance method" do
      temporary do
        reinit_example_models

        # Create a reference location
        reference = Location.create!(
          name: "Reference",
          coordinates: PG::Geo::Point.new(40.0, -74.0)
        )

        # Create nearby locations at different distances
        Location.create!(
          name: "Very Close",
          coordinates: PG::Geo::Point.new(40.001, -74.001)
        )
        Location.create!(
          name: "Close",
          coordinates: PG::Geo::Point.new(40.01, -74.01)
        )
        Location.create!(
          name: "Medium",
          coordinates: PG::Geo::Point.new(40.05, -74.05)
        )
        Location.create!(
          name: "Far",
          coordinates: PG::Geo::Point.new(41.0, -75.0)
        )

        # Test nearby_locations method with different parameters
        nearby_small_radius = reference.nearby_locations(radius: 0.02, max_results: 10)
        nearby_small_radius.size.should eq(2) # Should find "Very Close" and "Close"

        nearby_limited = reference.nearby_locations(radius: 0.1, max_results: 2)
        nearby_limited.size.should eq(2) # Should be limited to 2 results        # Verify the results are ordered by distance (closest first)
        names = nearby_limited.map(&.name)
        names.first.should eq("Very Close")
        names.last.should eq("Close")
      end
    end

    it "tests closest_to instance method" do
      temporary do
        reinit_example_models

        reference = Location.create!(
          name: "Reference",
          coordinates: PG::Geo::Point.new(40.0, -74.0)
        )

        Location.create!(
          name: "Closest",
          coordinates: PG::Geo::Point.new(40.001, -74.001)
        )
        Location.create!(
          name: "Farther",
          coordinates: PG::Geo::Point.new(40.01, -74.01)
        )
        Location.create!(
          name: "Farthest",
          coordinates: PG::Geo::Point.new(41.0, -75.0)
        )

        # Test closest_to method
        target_point = PG::Geo::Point.new(40.0005, -74.0005)
        closest = reference.closest_to(target_point)

        closest.should_not be_nil
        closest.not_nil!.name.should eq("Closest")
      end
    end

    it "tests farthest_from instance method" do
      temporary do
        reinit_example_models

        reference = Location.create!(
          name: "Reference",
          coordinates: PG::Geo::Point.new(40.0, -74.0)
        )

        Location.create!(
          name: "Close",
          coordinates: PG::Geo::Point.new(40.001, -74.001)
        )
        Location.create!(
          name: "Medium",
          coordinates: PG::Geo::Point.new(40.01, -74.01)
        )
        Location.create!(
          name: "Farthest",
          coordinates: PG::Geo::Point.new(41.0, -75.0)
        )

        # Test farthest_from method
        target_point = PG::Geo::Point.new(40.0, -74.0)
        farthest = reference.farthest_from(target_point)

        farthest.should_not be_nil
        farthest.not_nil!.name.should eq("Farthest")
      end
    end

    it "tests instance methods exclude self from results" do
      temporary do
        reinit_example_models

        reference = Location.create!(
          name: "Reference",
          coordinates: PG::Geo::Point.new(40.0, -74.0)
        )

        other = Location.create!(
          name: "Other",
          coordinates: PG::Geo::Point.new(40.01, -74.01)
        )

        # Test that instance methods exclude the reference location itself
        nearby = reference.nearby_locations(radius: 1.0, max_results: 10)
        nearby.map(&.id).should_not contain(reference.id)
        nearby.size.should eq(1)
        nearby[0].name.should eq("Other")

        closest = reference.closest_to(PG::Geo::Point.new(40.0, -74.0))
        closest.should_not be_nil
        closest.not_nil!.id.should_not eq(reference.id)
        closest.not_nil!.name.should eq("Other")

        farthest = reference.farthest_from(PG::Geo::Point.new(40.0, -74.0))
        farthest.should_not be_nil
        farthest.not_nil!.id.should_not eq(reference.id)
        farthest.not_nil!.name.should eq("Other")
      end
    end

    it "tests distance_to with non-existent record returns nil" do
      temporary do
        reinit_example_models

        location = Location.create!(
          name: "Test Location",
          coordinates: PG::Geo::Point.new(40.0, -74.0)
        )

        other_location = Location.create!(
          name: "Other Location",
          coordinates: PG::Geo::Point.new(40.01, -74.01)
        )

        # Delete the location to simulate non-existent record
        location.delete

        # distance_to should return nil for deleted/non-existent records
        distance = location.distance_to(other_location)
        distance.should be_nil
      end
    end
  end
end
