require "../spec_helper"

module OffsetLimitSpec
  describe Lustra::SQL::Query::OffsetLimit do
    describe "#limit" do
      it "accepts Int32" do
        query = Lustra::SQL.select.from(:users).limit(10)
        query.to_sql.should eq %(SELECT * FROM "users" LIMIT 10)
      end

      it "accepts Int64" do
        query = Lustra::SQL.select.from(:users).limit(10_i64)
        query.to_sql.should eq %(SELECT * FROM "users" LIMIT 10)
      end

      it "accepts nil" do
        query = Lustra::SQL.select.from(:users).limit(10).limit(nil)
        query.to_sql.should eq %(SELECT * FROM "users")
      end

      it "converts Int32 to Int64 internally" do
        query = Lustra::SQL.select.from(:users).limit(10)
        query.limit.should be_a(Int64)
        query.limit.should eq(10_i64)
      end
    end

    describe "#offset" do
      it "accepts Int32" do
        query = Lustra::SQL.select.from(:users).offset(20)
        query.to_sql.should eq %(SELECT * FROM "users" OFFSET 20)
      end

      it "accepts Int64" do
        query = Lustra::SQL.select.from(:users).offset(20_i64)
        query.to_sql.should eq %(SELECT * FROM "users" OFFSET 20)
      end

      it "accepts nil" do
        query = Lustra::SQL.select.from(:users).offset(20).offset(nil)
        query.to_sql.should eq %(SELECT * FROM "users")
      end

      it "converts Int32 to Int64 internally" do
        query = Lustra::SQL.select.from(:users).offset(20)
        query.offset.should be_a(Int64)
        query.offset.should eq(20_i64)
      end
    end

    describe "#clear_limit" do
      it "removes the limit clause" do
        query = Lustra::SQL.select.from(:users).limit(10).clear_limit
        query.to_sql.should eq %(SELECT * FROM "users")
        query.limit.should be_nil
      end
    end

    describe "#clear_offset" do
      it "removes the offset clause" do
        query = Lustra::SQL.select.from(:users).offset(20).clear_offset
        query.to_sql.should eq %(SELECT * FROM "users")
        query.offset.should be_nil
      end
    end

    describe "combined limit and offset" do
      it "generates correct SQL with both" do
        query = Lustra::SQL.select.from(:users).limit(10).offset(20)
        query.to_sql.should eq %(SELECT * FROM "users" LIMIT 10 OFFSET 20)
      end

      it "works with Int32 and Int64 mixed" do
        query = Lustra::SQL.select.from(:users).limit(10).offset(20_i64)
        query.to_sql.should eq %(SELECT * FROM "users" LIMIT 10 OFFSET 20)
      end

      it "handles clearing both" do
        query = Lustra::SQL.select.from(:users).limit(10).offset(20)
          .clear_limit.clear_offset
        query.to_sql.should eq %(SELECT * FROM "users")
      end
    end
  end
end
