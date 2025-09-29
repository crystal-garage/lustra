require "../../spec_helper"

module SelectSpec
  extend self

  def one_request
    Lustra::SQL
      .select("MAX(updated_at)")
      .from(:users)
  end

  describe Lustra::SQL::Query::Select do
    it "select wildcard *" do
      r = Lustra::SQL.select("*")
      r.to_sql.should eq "SELECT *"
    end

    it "select distinct" do
      r = Lustra::SQL.select("*").distinct
      r.to_sql.should eq "SELECT DISTINCT *"

      r = Lustra::SQL.select("a", "b", "c").distinct
      r.to_sql.should eq "SELECT DISTINCT a, b, c"

      r = Lustra::SQL.select(:first_name, :last_name, :id).distinct
      r.to_sql.should eq "SELECT DISTINCT \"first_name\", \"last_name\", \"id\""
    end

    it "select any string" do
      r = Lustra::SQL.select("1")
      r.to_sql.should eq "SELECT 1"
    end

    it "select using variables" do
      r = Lustra::SQL.select("SUM(quantity) AS sum", "COUNT(*) AS count")
      # No escape with string, escape must be done manually
      r.to_sql.should eq "SELECT SUM(quantity) AS sum, COUNT(*) AS count"
    end

    it "select using multiple strings" do
      r = Lustra::SQL.select({uid: "user_id", some_cool_stuff: "column"})
      r.to_sql.should eq "SELECT user_id AS uid, column AS some_cool_stuff"
    end

    it "reset the select" do
      r = Lustra::SQL.select("1").clear_select.select("2")
      r.to_sql.should eq "SELECT 2"
    end

    it "select a subquery" do
      r = Lustra::SQL.select({max_updated_at: one_request})
      r.to_sql.should eq "SELECT ( #{one_request.to_sql} ) AS max_updated_at"
    end
  end
end
