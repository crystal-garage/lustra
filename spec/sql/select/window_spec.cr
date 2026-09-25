require "../../spec_helper"

module WindowSpec
  describe Lustra::SQL::Query::Window do
    it "omits WINDOW when no windows are defined" do
      query = Lustra::SQL.select.from(:users)

      query.windows.should be_empty
      query.to_sql.should eq %(SELECT * FROM "users")
    end

    it "accepts a window name and definition" do
      query = Lustra::SQL.select("ROW_NUMBER() OVER ranked").from(:users)

      query.window(:ranked, "(ORDER BY id)").should be(query)
      query.windows.should eq([{"ranked", "(ORDER BY id)"}])
      query.to_sql.should eq %(SELECT ROW_NUMBER() OVER ranked FROM "users" WINDOW ranked AS (ORDER BY id))
    end

    it "accepts multiple windows as a named tuple" do
      query = Lustra::SQL.select.from(:users)

      query.window({ranked: "(ORDER BY id)", grouped: "(PARTITION BY role_id)"}).should be(query)
      query.to_sql.should eq %(SELECT * FROM "users" WINDOW ranked AS (ORDER BY id), grouped AS (PARTITION BY role_id))
    end

    it "appends windows across calls" do
      query = Lustra::SQL.select.from(:users)
        .window("grouped", "(PARTITION BY role_id)")
        .window({ranked: "(grouped ORDER BY id)"})

      query.to_sql.should eq %(SELECT * FROM "users" WINDOW grouped AS (PARTITION BY role_id), ranked AS (grouped ORDER BY id))
    end

    it "clears windows on a copy without changing the original and allows reuse" do
      original = Lustra::SQL.select.from(:users).where(id: 1).order_by(:id).limit(2)
        .window(:ranked, "(ORDER BY id)").window(:grouped, "(PARTITION BY role_id)")
      original_sql = original.to_sql
      copy = original.dup

      copy.to_sql.should eq(original_sql)
      copy.clear_windows.should be(copy)
      copy.windows.should be_empty
      copy.to_sql.should eq %(SELECT * FROM "users" WHERE ("id" = 1) ORDER BY "id" ASC LIMIT 2)
      original.windows.size.should eq(2)
      original.to_sql.should eq(original_sql)

      copy.window(:replacement, "(ORDER BY id DESC)")
      copy.to_sql.should eq %(SELECT * FROM "users" WHERE ("id" = 1) WINDOW replacement AS (ORDER BY id DESC) ORDER BY "id" ASC LIMIT 2)
    end

    it "executes partitioned rankings and running totals using multiple windows" do
      query = Lustra::SQL.select("bucket", "value", "ROW_NUMBER() OVER ranked AS position", "SUM(value) OVER running AS total")
        .from("(VALUES ('a', 2), ('a', 5), ('b', 3)) AS entries(bucket, value)")
        .window({ranked: "(PARTITION BY bucket ORDER BY value)", running: "(ranked ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)"})
        .order_by(:bucket).order_by(:value)

      query.to_a.map { |row| {row["bucket"], row["value"], row["position"], row["total"]} }
        .should eq([{"a", 2, 1_i64, 2_i64}, {"a", 5, 2_i64, 7_i64}, {"b", 3, 1_i64, 3_i64}])
    end

    it "places windows after grouping and HAVING and before ordering and pagination" do
      query = Lustra::SQL.select("bucket", "COUNT(*) AS total", "ROW_NUMBER() OVER ranked AS position")
        .from("(VALUES ('a'), ('a'), ('b'), ('c'), ('c'), ('c')) AS entries(bucket)")
        .where("bucket <> 'skip'").group_by(:bucket).having("COUNT(*) > 1")
        .window(:ranked, "(ORDER BY COUNT(*) DESC)").order_by(:position).limit(1).offset(1)

      query.to_a.map { |row| {row["bucket"], row["total"], row["position"]} }
        .should eq([{"a", 2_i64, 2_i64}])
    end
  end
end
