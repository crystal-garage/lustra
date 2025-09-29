require "../../spec_helper"

module BoolConverterSpec
  describe "Lustra::Model::Converter::BoolConverter" do
    it "converts from boolean" do
      converter = Lustra::Model::Converter::BoolConverter
      converter.to_column(1).should be_true
      converter.to_column(-1).should be_true
      converter.to_column(0).should be_false
      converter.to_column(0.0).should be_false
      converter.to_column(2).should be_true
      converter.to_column(1.0).should be_true

      converter.to_column(true).should be_true
      converter.to_column(false).should be_false

      converter.to_column("f").should be_false
      converter.to_column("t").should be_true
      converter.to_column("false").should be_false
      converter.to_column("true").should be_true

      converter.to_column(nil).should be_nil

      # Anything else than string or number is true
      converter.to_column([] of String).should be_true
    end

    it "transform boolean to 't' and 'f'" do
      converter = Lustra::Model::Converter::BoolConverter
      converter.to_db(true).should eq("t")
      converter.to_db(false).should eq("f")
      # To ensure we can use the converter with Bool? type.
      converter.to_db(nil).should be_nil
    end
  end
end
