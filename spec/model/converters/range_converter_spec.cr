require "../../spec_helper"

module RangeConverterSpec
  describe "Lustra::Model::Converter Range Converters" do
    describe "RangeConverter(Int32)" do
      it "parses and serializes int ranges" do
        converter = Lustra::Model::Converter::RangeConverter(Int32)

        # parse textual range
        r = converter.to_column("[1,10)")
        r.should eq(1...10)

        # serialize Range -> PG textual
        serialized = converter.to_db(converter.to_column(Range.new(1_i32, 10_i32, true)))
        serialized.should eq("[1,10)")

        # empty remains distinct from SQL NULL
        converter.to_column("empty").not_nil!.empty?.should be_true

        # unbounded lower bound
        r2 = converter.to_column("(,10]")
        r2.should eq(..10)
      end
    end

    describe "RangeConverter(Int64)" do
      it "parses and serializes big int ranges" do
        converter = Lustra::Model::Converter::RangeConverter(Int64)

        r = converter.to_column("[10000000000,20000000000)")
        r.should eq(10000000000...20000000000)

        serialized = converter.to_db(converter.to_column(Range.new(10000000000, 20000000000, true)))
        serialized.should eq("[10000000000,20000000000)")

        # endless upper bound
        r2 = converter.to_column("[1,)")
        r2.should eq(1...)
      end
    end

    it "preserves bound flags when converting PostgreSQL range values" do
      converter = Lustra::Model::Converter::RangeConverter(BigDecimal)
      {true, false}.each do |lower_inclusive|
        {true, false}.each do |upper_inclusive|
          value = PG::Range(Int32).new(1, 10,
            lower_inclusive: lower_inclusive, upper_inclusive: upper_inclusive)
          converted = converter.to_column(value).not_nil!
          converted.begin.should eq(BigDecimal.new(1))
          converted.end.should eq(BigDecimal.new(10))
          converted.lower_inclusive.should eq(lower_inclusive)
          converted.upper_inclusive.should eq(upper_inclusive)
        end
      end
    end

    it "parses numeric strings without losing decimal precision" do
      converter = Lustra::Model::Converter::RangeConverter(PG::Numeric)
      {"0", "-0.00001", "12345678901234567890.123456789", "1e-20", "1.2300"}.each do |text|
        value = converter.to_column("[#{text},#{text}]").not_nil!
        BigDecimal.new(value.begin.to_s).should eq(BigDecimal.new(text))
        BigDecimal.new(value.end.to_s).should eq(BigDecimal.new(text))
      end
    end

    it "rejects malformed and empty textual input instead of treating it as SQL NULL" do
      converter = Lustra::Model::Converter::RangeConverter(Int32)
      {"", "[1,2", "[1,2,3]", %(["1,2]), %(["",2]), %(["1""2",3])}.each do |text|
        expect_raises(ArgumentError) { converter.to_column(text) }
      end
    end

    describe "RangeConverter(Time)" do
      it "parses PostgreSQL ISO timestamps and preserves time zone offsets" do
        converter = Lustra::Model::Converter::RangeConverter(Time)
        value = converter.to_column(%(["2024-01-01 10:30:00.123456+02","2024-01-01 12:30:00+02"])).not_nil!
        value.begin.should eq(Time.utc(2024, 1, 1, 8, 30, 0, nanosecond: 123_456_000))
        value.end.should eq(Time.utc(2024, 1, 1, 10, 30))
        converter.to_db(value).should eq("[2024-01-01T08:30:00.123456000Z,2024-01-01T10:30:00.000000000Z]")
      end

      it "parses and serializes time ranges" do
        converter = Lustra::Model::Converter::RangeConverter(Time)

        txt = "[2020-01-01T00:00:00Z,2020-12-31T23:59:59Z]"
        r = converter.to_column(txt)
        start_t = Time.utc(2020, 1, 1)
        end_t = Time.utc(2020, 12, 31, 23, 59, 59)
        r.should eq(start_t..end_t)

        serialized = converter.to_db(converter.to_column(Range.new(start_t, end_t, false)))
        serialized.should eq("[2020-01-01T00:00:00.000000000Z,2020-12-31T23:59:59.000000000Z]")

        # unbounded both sides (both bounds empty)
        r2 = converter.to_column("(,)")
        r2.should eq(...)
      end
    end
  end
end
