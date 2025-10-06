require "spec"

require "../spec_helper"

module UpdateSpec
  extend self

  describe "Lustra::SQL" do
    describe "UpdateQuery" do
      it "allows usage of unsafe SQL fragment" do
        Lustra::SQL.update(:model)
          .set("array": Lustra::SQL.unsafe("array_replace(array, 'a', 'b')")
          ).to_sql.should eq %(UPDATE "model" SET "array" = array_replace(array, 'a', 'b'))
      end
    end
  end
end
