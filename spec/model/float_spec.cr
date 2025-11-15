require "../spec_helper"
require "../data/example_models"

module FloatSpec
  describe "Float32 and Float64 column support" do
    it "creates and retrieves Float32 and Float64 values" do
      temporary do
        reinit_example_models

        # Create with Float32 (real) and Float64 (double precision)
        data = FloatData.create!({
          price:       19.99_f32,
          latitude:    37.7749_f64,
          longitude:   -122.4194_f64,
          temperature: -5.5_f32,
        })

        data.price.should be_close(19.99_f32, 0.01)
        data.latitude.should_not be_nil
        data.latitude.not_nil!.should be_close(37.7749_f64, 0.0001)
        data.longitude.should_not be_nil
        data.longitude.not_nil!.should be_close(-122.4194_f64, 0.0001)
        data.temperature.should_not be_nil
        data.temperature.not_nil!.should be_close(-5.5_f32, 0.01)

        # Retrieve and verify
        retrieved = FloatData.find!(data.id)
        retrieved.price.should be_close(19.99_f32, 0.01)
        retrieved.latitude.should_not be_nil
        retrieved.latitude.not_nil!.should be_close(37.7749_f64, 0.0001)
        retrieved.longitude.should_not be_nil
        retrieved.longitude.not_nil!.should be_close(-122.4194_f64, 0.0001)
        retrieved.temperature.should_not be_nil
        retrieved.temperature.not_nil!.should be_close(-5.5_f32, 0.01)
      end
    end

    it "updates Float32 and Float64 values" do
      temporary do
        reinit_example_models

        data = FloatData.create!({
          price:       10.50_f32,
          latitude:    40.7128_f64,
          longitude:   -74.0060_f64,
          temperature: 22.5_f32,
        })

        data.price = 15.75_f32
        data.latitude = 51.5074_f64
        data.longitude = -0.1278_f64
        data.temperature = 18.3_f32
        data.save!

        retrieved = FloatData.find!(data.id)
        retrieved.price.should be_close(15.75_f32, 0.01)
        retrieved.latitude.should_not be_nil
        retrieved.latitude.not_nil!.should be_close(51.5074_f64, 0.0001)
        retrieved.longitude.should_not be_nil
        retrieved.longitude.not_nil!.should be_close(-0.1278_f64, 0.0001)
        retrieved.temperature.should_not be_nil
        retrieved.temperature.not_nil!.should be_close(18.3_f32, 0.01)
      end
    end

    it "queries with Float32 and Float64 conditions" do
      temporary do
        reinit_example_models

        FloatData.create!({price: 10.00_f32, latitude: 10.0_f64, longitude: 20.0_f64, temperature: 15.0_f32})
        FloatData.create!({price: 20.00_f32, latitude: 20.0_f64, longitude: 30.0_f64, temperature: 25.0_f32})
        FloatData.create!({price: 30.00_f32, latitude: 30.0_f64, longitude: 40.0_f64, temperature: 35.0_f32})

        # Query by Float32
        results = FloatData.query.where { price > 15.0_f32 }
        results.size.should eq(2)

        # Query by Float64
        results = FloatData.query.where { latitude >= 20.0_f64 }
        results.size.should eq(2)

        # Query with range
        results = FloatData.query.where { temperature.in?(20.0_f32..30.0_f32) }
        results.size.should eq(1)
        first_result = results.first!
        first_result.temperature.should_not be_nil
        first_result.temperature.not_nil!.should be_close(25.0_f32, 0.01)
      end
    end

    it "handles precision correctly for Float32 vs Float64" do
      temporary do
        reinit_example_models

        # Float32 has ~7 decimal digits of precision
        # Float64 has ~15 decimal digits of precision
        data = FloatData.create!({
          price:       3.1415927_f32,           # Float32
          latitude:    3.141592653589793_f64,   # Float64
          longitude:   -122.41941234567890_f64, # Float64
          temperature: nil,
        })

        retrieved = FloatData.find!(data.id)

        # Float32 precision check (approximately 7 digits)
        retrieved.price.should be_close(3.1415927_f32, 0.0000001)

        # Float64 precision check (approximately 15 digits)
        retrieved.latitude.should_not be_nil
        retrieved.latitude.not_nil!.should be_close(3.141592653589793_f64, 0.000000000000001)
        retrieved.longitude.should_not be_nil
        retrieved.longitude.not_nil!.should be_close(-122.41941234567890_f64, 0.00000000000001)
      end
    end

    it "handles special float values" do
      temporary do
        reinit_example_models

        # Test with very small and very large values
        data = FloatData.create!({
          price:       0.01_f32,
          latitude:    1e-10_f64,
          longitude:   -1e10_f64,
          temperature: 1000.0_f32,
        })

        retrieved = FloatData.find!(data.id)
        retrieved.price.should be_close(0.01_f32, 0.0001)
        retrieved.latitude.should_not be_nil
        retrieved.latitude.not_nil!.should be_close(1e-10_f64, 1e-15)
        retrieved.longitude.should_not be_nil
        retrieved.longitude.not_nil!.should be_close(-1e10_f64, 1e5)
        retrieved.temperature.should_not be_nil
        retrieved.temperature.not_nil!.should be_close(1000.0_f32, 0.01)
      end
    end

    it "can convert between different numeric types" do
      temporary do
        reinit_example_models

        # Creating with different number types should convert properly
        data = FloatData.create!({
          price:       20,   # Int -> Float32
          latitude:    40.5, # Float64
          longitude:   -74,  # Int -> Float64
          temperature: 25.5, # Float64 -> Float32
        })

        retrieved = FloatData.find!(data.id)
        retrieved.price.should be_close(20.0_f32, 0.01)
        retrieved.latitude.should_not be_nil
        retrieved.latitude.not_nil!.should be_close(40.5_f64, 0.01)
        retrieved.longitude.should_not be_nil
        retrieved.longitude.not_nil!.should be_close(-74.0_f64, 0.01)
        retrieved.temperature.should_not be_nil
        retrieved.temperature.not_nil!.should be_close(25.5_f32, 0.01)
      end
    end
  end
end
