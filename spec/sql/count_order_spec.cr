require "../spec_helper"

class Fiber
  # Capture only this spec fiber's queries, including when other specs use
  # parallel execution contexts.
  property count_order_spec_queries : Array(String)?
end

module Lustra::SQL::Logger
  def log_query(sql, &)
    Fiber.current.count_order_spec_queries.try(&.push(sql.to_s))
    previous_def(sql) { yield }
  end
end

module CountOrderSpec
  def self.capture_count_sql(&)
    queries = [] of String
    Fiber.current.count_order_spec_queries = queries
    yield
    queries.size.should eq(1)
    queries.first
  ensure
    Fiber.current.count_order_spec_queries = nil
  end

  describe "Count ordering" do
    it "avoids sorting ordinary counts without changing the original query" do
      query = Lustra::SQL.select(:value)
        .from("generate_series(1, 100) AS entries(value)")
        .order_by(:value, :desc)
      original_sql = query.to_sql

      sql = capture_count_sql { query.count.should eq(100_i64) }
      query.to_sql.should eq(original_sql)
      query.limit(2).to_a.map(&.["value"]).should eq([100, 99])

      plan = Lustra::SQL::ConnectionPool.with_connection("default") do |connection|
        connection.query_all("EXPLAIN #{sql}", as: String)
      end
      plan.any?(&.includes?("Sort")).should be_false
    end

    it "retains ordering and row boundaries for paginated counts" do
      query = Lustra::SQL.select(:value)
        .from("(VALUES (1), (2), (3), (4)) AS entries(value)")
        .order_by(:value, :desc).limit(2).offset(1)
      original_sql = query.to_sql

      sql = capture_count_sql { query.count.should eq(2_i64) }
      sql.should contain(%(ORDER BY "value" DESC))
      query.to_sql.should eq(original_sql)
      query.to_a.map(&.["value"]).should eq([3, 2])
    end

    it "retains ordering for DISTINCT ON counts" do
      query = Lustra::SQL.select(:id, :value)
        .from("(VALUES (1, 10), (1, 30), (2, 20), (2, 40)) AS entries(id, value)")
        .distinct("id").order_by(:id).order_by(:value, :desc)
      original_sql = query.to_sql

      sql = capture_count_sql { query.count.should eq(2_i64) }
      sql.should contain(%(ORDER BY "id" ASC, "value" DESC))
      query.to_sql.should eq(original_sql)
      query.to_a.map(&.["value"]).should eq([30, 40])
    end
  end
end
