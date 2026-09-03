require "../../src/lustra"
require "benchmark"

# Initialize the connection
`echo "DROP DATABASE IF EXISTS benchmark_lustra;" | psql -U postgres`
`echo "CREATE DATABASE benchmark_lustra;" | psql -U postgres`
Lustra::SQL.init("postgres://postgres@localhost/benchmark_lustra")

init = <<-SQL
    CREATE TABLE benchmark (id serial PRIMARY KEY NOT NULL, y int);
    CREATE INDEX benchmark_y ON benchmark (y);

    INSERT INTO benchmark
    SELECT i AS x, 2*i AS y
    FROM generate_series(1, 1000000) AS i;
  end
  SQL

init.split(";").each { |sql| Lustra::SQL.execute(sql) }

class BenchmarkModel
  include Lustra::Model

  self.table = "benchmark"

  primary_key

  column y : Int32
end

LIMIT = 100_000

puts "Starting benchmarking, total to fetch = #{BenchmarkModel.query.count} records"

Benchmark.ips(warmup: 2.seconds, calculation: 5.seconds) do |x|
  x.report("With Model: Simple load 100k") do
    BenchmarkModel.query.limit(LIMIT).to_a
  end

  x.report("With Model: With cursor") do
    a = [] of BenchmarkModel
    BenchmarkModel.query.limit(LIMIT).each_with_cursor { |o| a << o }
  end

  x.report("With Model: With attributes") do
    BenchmarkModel.query.limit(LIMIT).to_a(fetch_columns: true)
  end

  x.report("With Model: With attributes and cursor") do
    a = [] of BenchmarkModel
    BenchmarkModel.query.limit(LIMIT).each_with_cursor(fetch_columns: true) { |h| a << h }
  end

  x.report("Hash from SQL only") do
    a = [] of Hash(String, ::Lustra::SQL::Any)
    BenchmarkModel.query.limit(LIMIT).fetch { |h| a << h.dup }
  end

  x.report("Raw SQL typed streaming") do
    a = [] of Hash(String, ::Lustra::SQL::Any)

    Lustra::SQL::ConnectionPool.with_connection("default") do |cnx|
      cnx.query("SELECT id, y FROM benchmark LIMIT #{LIMIT}") do |rs|
        rs.each do
          a << {"id" => rs.read(Int32), "y" => rs.read(Int32)} of String => Lustra::SQL::Any
        end
      end
    end
  end
end
