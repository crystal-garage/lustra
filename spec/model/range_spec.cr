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
          numeric_range: BigDecimal.new("1.5")..BigDecimal.new("2.5"),
          time_range: Time.utc(2024, 1, 1)..Time.utc(2024, 12, 31)
        )

        range_record.int32_range.should eq(1...11)
        range_record.int64_range.should eq(1000...2001)
        range_record.numeric_range.should eq(BigDecimal.new("1.5")..BigDecimal.new("2.5"))
        range_record.time_range.should eq(Time.utc(2024, 1, 1)..Time.utc(2024, 12, 31))
      end
    end

    it "creates and retrieves records with endless/beginless range" do
      temporary do
        reinit_example_models

        range_record = RangeData.create!(
          name: "Test Range Record",
          int32_range: ..10,
          int64_range: 1000..,
          numeric_range: ..BigDecimal.new("2.5"),
          time_range: Time.utc(2024, 1, 1)..
        )

        range_record.int32_range.should eq(...11)
        range_record.int64_range.should eq(1000...)
        range_record.numeric_range.should eq(..BigDecimal.new("2.5"))
        range_record.time_range.should eq(Time.utc(2024, 1, 1)...)
      end
    end

    it "preserves empty, unbounded, and null range values separately" do
      temporary do
        reinit_example_models
        {nil, "empty", "(,)"}.each do |input|
          record = RangeData.create!(int32_range: input, int64_range: input,
            numeric_range: input, pg_numeric_range: input, time_range: input)
          record.reload
          {record.int32_range, record.int64_range, record.numeric_range, record.pg_numeric_range, record.time_range}.each do |value|
            if input.nil?
              value.should be_nil
            else
              value = value.not_nil!
              value.empty?.should eq(input == "empty")
              value.begin.should be_nil
              value.end.should be_nil
              value.lower_inclusive.should be_false
              value.upper_inclusive.should be_false
            end
          end
        end
      end
    end

    it "preserves exclusive lower bounds in strings and decoded values" do
      temporary do
        reinit_example_models
        record = RangeData.create!(
          int32_range: "(1,10]",
          int64_range: "(100,200)",
          numeric_range: "(1.5,2.5]",
          pg_numeric_range: "(1.5,2.5]",
          time_range: "(\"2024-01-01 00:00:00\",\"2024-02-01 00:00:00\"]"
        )
        record.reload
        record.int32_range.should eq(2...11)
        record.int64_range.should eq(101_i64...200_i64)
        {record.numeric_range, record.pg_numeric_range, record.time_range}.each do |value|
          value = value.not_nil!
          value.lower_inclusive.should be_false
          value.upper_inclusive.should be_true
        end
        record.numeric_range.not_nil!.begin.should eq(BigDecimal.new("1.5"))
        record.pg_numeric_range.not_nil!.begin.to_s.should eq("1.5")
        record.time_range.not_nil!.begin.should eq(Time.utc(2024, 1, 1))
      end
    end

    it "keeps fully unbounded native range input nonempty" do
      temporary do
        reinit_example_models
        record = RangeData.create!(int32_range: Range(Int32?, Int32?).new(nil, nil, true))
        record.int32_range.not_nil!.empty?.should be_false
        Lustra::SQL.select("isempty(int32_range)").from(:range_data)
          .where(id: record.id).scalar(Bool).should be_false
      end
    end

    it "filters range columns with native and model range values" do
      temporary do
        reinit_example_models
        record = RangeData.create!(int32_range: 1..10,
          numeric_range: "(1.5,2.5]", time_range: Time.utc(2024, 1, 1)..Time.utc(2024, 2, 1))
        RangeData.query.where { int32_range == record.int32_range }.count.should eq(1_i64)
        RangeData.query.where { int32_range == (1..10) }.count.should eq(1_i64)
        RangeData.query.where { numeric_range == record.numeric_range }.count.should eq(1_i64)
        RangeData.query.where { time_range == record.time_range }.count.should eq(1_i64)
        RangeData.create!(int32_range: "empty")
        RangeData.query.where { int32_range == PG::Range(Int32).empty }.count.should eq(1_i64)
      end
    end

    it "inserts PostgreSQL ranges through low-level queries" do
      temporary do
        reinit_example_models
        Lustra::SQL.insert(:range_data, {int32_range: PG::Range(Int32).new(1, 10, upper_inclusive: true)}).execute
        Lustra::SQL.insert(:range_data, {int32_range: PG::Range(Int32).empty}).execute
        records = RangeData.query.order_by(:id).to_a
        records[0].int32_range.should eq(1...11)
        records[1].int32_range.not_nil!.empty?.should be_true
      end
    end

    it "preserves range metadata through direct column updates and JSON" do
      temporary do
        reinit_example_models
        record = RangeData.create!(int32_range: 1..10)
        value = PG::Range(BigDecimal).new(BigDecimal.new("1.5"), BigDecimal.new("2.5"),
          lower_inclusive: false, upper_inclusive: true)
        record.update_column(:numeric_range, value)
        record.reload.numeric_range.should eq(value)
        JSON.parse(record.to_json)["numeric_range"].as_s.should eq("(1.5,2.5]")
      end
    end

    it "creates and retrieves records with raw sql range" do
      temporary do
        reinit_example_models

        range_record = RangeData.create!(
          name: "Test Range Record",
          int32_range: "[,11)",
          int64_range: "[1000,)",
          numeric_range: "[1.5,2.5]",
        )

        range_record.int32_range.should eq(...11)
        range_record.int64_range.should eq(1000...)
        range_record.numeric_range.should eq(BigDecimal.new("1.5")..BigDecimal.new("2.5"))
      end
    end
  end
end
