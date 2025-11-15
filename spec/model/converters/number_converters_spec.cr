require "../../spec_helper"

module NumberConvertersSpec
  describe "Lustra::Model::Converter Number Converters" do
    describe "Int8Converter" do
      it "converts to column" do
        converter = Lustra::Model::Converter::Int8Converter
        converter.to_column(42).should eq(42_i8)
        converter.to_column(42_i16).should eq(42_i8)
        converter.to_column(42_i32).should eq(42_i8)
        converter.to_column(42_i64).should eq(42_i8)
        converter.to_column("42").should eq(42_i8)
        converter.to_column(nil).should be_nil
      end

      it "converts to db" do
        converter = Lustra::Model::Converter::Int8Converter
        converter.to_db(42_i8).should eq(42_i8)
        converter.to_db(nil).should be_nil
      end
    end

    describe "Int16Converter" do
      it "converts to column" do
        converter = Lustra::Model::Converter::Int16Converter
        converter.to_column(1000).should eq(1000_i16)
        converter.to_column("1000").should eq(1000_i16)
        converter.to_column(nil).should be_nil
      end

      it "converts to db" do
        converter = Lustra::Model::Converter::Int16Converter
        converter.to_db(1000_i16).should eq(1000_i16)
        converter.to_db(nil).should be_nil
      end
    end

    describe "Int32Converter" do
      it "converts to column" do
        converter = Lustra::Model::Converter::Int32Converter
        converter.to_column(100000).should eq(100000_i32)
        converter.to_column("100000").should eq(100000_i32)
        converter.to_column(nil).should be_nil
      end

      it "converts to db" do
        converter = Lustra::Model::Converter::Int32Converter
        converter.to_db(100000_i32).should eq(100000_i32)
        converter.to_db(nil).should be_nil
      end
    end

    describe "Int64Converter" do
      it "converts to column" do
        converter = Lustra::Model::Converter::Int64Converter
        converter.to_column(9223372036854775807).should eq(9223372036854775807_i64)
        converter.to_column("9223372036854775807").should eq(9223372036854775807_i64)
        converter.to_column(nil).should be_nil
      end

      it "converts to db" do
        converter = Lustra::Model::Converter::Int64Converter
        converter.to_db(9223372036854775807_i64).should eq(9223372036854775807_i64)
        converter.to_db(nil).should be_nil
      end
    end

    describe "UInt8Converter" do
      it "converts to column" do
        converter = Lustra::Model::Converter::UInt8Converter
        converter.to_column(255).should eq(255_u8)
        converter.to_column("255").should eq(255_u8)
        converter.to_column(nil).should be_nil
      end

      it "converts to db" do
        converter = Lustra::Model::Converter::UInt8Converter
        converter.to_db(255_u8).should eq(255_u8)
        converter.to_db(nil).should be_nil
      end
    end

    describe "UInt16Converter" do
      it "converts to column" do
        converter = Lustra::Model::Converter::UInt16Converter
        converter.to_column(65535).should eq(65535_u16)
        converter.to_column("65535").should eq(65535_u16)
        converter.to_column(nil).should be_nil
      end

      it "converts to db" do
        converter = Lustra::Model::Converter::UInt16Converter
        converter.to_db(65535_u16).should eq(65535_u16)
        converter.to_db(nil).should be_nil
      end
    end

    describe "UInt32Converter" do
      it "converts to column" do
        converter = Lustra::Model::Converter::UInt32Converter
        converter.to_column(4294967295).should eq(4294967295_u32)
        converter.to_column("4294967295").should eq(4294967295_u32)
        converter.to_column(nil).should be_nil
      end

      it "converts to db" do
        converter = Lustra::Model::Converter::UInt32Converter
        converter.to_db(4294967295_u32).should eq(4294967295_u32)
        converter.to_db(nil).should be_nil
      end
    end

    describe "UInt64Converter" do
      it "converts to column" do
        converter = Lustra::Model::Converter::UInt64Converter
        converter.to_column(18446744073709551615_u64).should eq(18446744073709551615_u64)
        converter.to_column("18446744073709551615").should eq(18446744073709551615_u64)
        converter.to_column(nil).should be_nil
      end

      it "converts to db" do
        converter = Lustra::Model::Converter::UInt64Converter
        converter.to_db(18446744073709551615_u64).should eq(18446744073709551615_u64)
        converter.to_db(nil).should be_nil
      end
    end

    describe "Float32Converter (real)" do
      it "converts to column" do
        converter = Lustra::Model::Converter::Float32Converter
        result = converter.to_column(3.14)
        result.should_not be_nil
        result.not_nil!.should be_close(3.14_f32, 0.001)

        result = converter.to_column(3.14_f64)
        result.should_not be_nil
        result.not_nil!.should be_close(3.14_f32, 0.001)

        result = converter.to_column("3.14")
        result.should_not be_nil
        result.not_nil!.should be_close(3.14_f32, 0.001)

        result = converter.to_column(-123.456)
        result.should_not be_nil
        result.not_nil!.should be_close(-123.456_f32, 0.001)

        converter.to_column(nil).should be_nil
      end

      it "converts to db" do
        converter = Lustra::Model::Converter::Float32Converter
        result = converter.to_db(3.14_f32)
        result.should_not be_nil
        result.not_nil!.should be_close(3.14_f32, 0.001)
        converter.to_db(nil).should be_nil
      end
    end

    describe "Float64Converter (double precision)" do
      it "converts to column" do
        converter = Lustra::Model::Converter::Float64Converter
        result = converter.to_column(3.141592653589793)
        result.should_not be_nil
        result.not_nil!.should be_close(3.141592653589793_f64, 0.000000000000001)

        result = converter.to_column(3.14_f32)
        result.should_not be_nil
        result.not_nil!.should be_close(3.14_f64, 0.001)

        result = converter.to_column("3.141592653589793")
        result.should_not be_nil
        result.not_nil!.should be_close(3.141592653589793_f64, 0.000000000000001)

        result = converter.to_column(-123.456789012345)
        result.should_not be_nil
        result.not_nil!.should be_close(-123.456789012345_f64, 0.000000000001)

        converter.to_column(nil).should be_nil
      end

      it "converts to db" do
        converter = Lustra::Model::Converter::Float64Converter
        result = converter.to_db(3.141592653589793_f64)
        result.should_not be_nil
        result.not_nil!.should be_close(3.141592653589793_f64, 0.000000000000001)
        converter.to_db(nil).should be_nil
      end
    end

    describe "BigIntConverter" do
      it "converts to column" do
        converter = Lustra::Model::Converter::BigIntConverter
        big_num = BigInt.new("12345678901234567890")
        converter.to_column("12345678901234567890").should eq(big_num)
        converter.to_column(123).should eq(BigInt.new(123))
        converter.to_column(nil).should be_nil
      end

      it "converts to db" do
        converter = Lustra::Model::Converter::BigIntConverter
        big_num = BigInt.new("12345678901234567890")
        converter.to_db(big_num).should eq(big_num)
        converter.to_db(nil).should be_nil
      end
    end

    describe "BigFloatConverter" do
      it "converts to column" do
        converter = Lustra::Model::Converter::BigFloatConverter
        converter.to_column(3.14).should eq(BigFloat.new(3.14))
        converter.to_column("3.14159265358979323846").should eq(BigFloat.new("3.14159265358979323846"))
        converter.to_column(nil).should be_nil
      end

      it "converts to db" do
        converter = Lustra::Model::Converter::BigFloatConverter
        big_float = BigFloat.new("3.14159265358979323846")
        converter.to_db(big_float).should eq(big_float)
        converter.to_db(nil).should be_nil
      end
    end

    describe "BigDecimalConverter" do
      it "converts to column" do
        converter = Lustra::Model::Converter::BigDecimalConverter
        converter.to_column(42.0123).should eq(BigDecimal.new(BigInt.new(420123), 4))
        converter.to_column("42_42_42_24.0123_456_789").should eq(BigDecimal.new(BigInt.new(424242240123456789), 10))
        converter.to_column(BigDecimal.new("-0.1029387192083710928371092837019283701982370918237"))
          .should eq(BigDecimal.new(BigInt.new("-1029387192083710928371092837019283701982370918237".to_big_i), 49))
        converter.to_column(nil).should be_nil
      end

      it "converts to db" do
        converter = Lustra::Model::Converter::BigDecimalConverter
        bd = BigDecimal.new(BigInt.new(420123), 4)
        converter.to_db(bd).should eq(bd)
        converter.to_db(nil).should be_nil
      end
    end
  end
end
