require "../spec_helper"
require "../data/example_models"

module RangeSpec
  describe "PostgreSQL Range Types Test Suite" do
    it "creates and retrieves records with range" do
      temporary do
        reinit_example_models

        range_record = RangeData.create!(
          name: "Test Range Record",
          int32_range: 1..10,
          int64_range: 1000..2000,
          time_range: Time.utc(2024, 1, 1)..Time.utc(2024, 12, 31)
        )

        range_record.int32_range.should eq(1...11)
        range_record.int64_range.should eq(1000...2001)
        range_record.time_range.should eq(Time.utc(2024, 1, 1)..Time.utc(2024, 12, 31))
      end
    end
  end
end
