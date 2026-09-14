require "../spec_helper"

abstract class DB::Connection
  # Spec-only inspection of the installed driver's per-connection cache.
  def statement_cache_spec_size
    count = 0
    @statements_cache.each_value { |_| count += 1 }
    count
  end
end

class Lustra::SQL::ConnectionPool
  def self.cleanup_statement_cache_spec(name : String)
    @@databases.delete(name).try(&.close)
  end
end

module StatementCacheSpec
  NAME = "statement_cache_spec"

  def self.with_pool(options = "", &)
    url = "postgres://#{postgres_user}:#{postgres_password}@#{postgres_host}/lustra_spec#{options}"
    Lustra::SQL.init(NAME, url)
    Lustra::SQL::ConnectionPool.with_connection(NAME) { |connection| yield connection }
  ensure
    Lustra::SQL::ConnectionPool.cleanup_statement_cache_spec(NAME)
  end

  describe "Lustra statement cache defaults" do
    it "does not retain a statement for each distinct literal SELECT by default" do
      with_pool do |connection|
        before = connection.statement_cache_spec_size
        50.times do |value|
          Lustra::SQL.select("#{value} AS value").use_connection(NAME).scalar(Int32).should eq(value)
        end

        connection.statement_cache_spec_size.should eq(before)
      end
    end

    it "does not retain a statement for each RETURNING insert by default" do
      with_pool do |connection|
        connection.exec_all("CREATE TEMP TABLE statement_cache_rows (id integer PRIMARY KEY)")
        before = connection.statement_cache_spec_size
        20.times do |value|
          row = Lustra::SQL.insert_into("statement_cache_rows", {id: value}).returning("id").execute(NAME)
          row["id"].should eq(value)
        end

        connection.statement_cache_spec_size.should eq(before)
      end
    end

    it "honors explicit statement-cache opt-in" do
      with_pool("?prepared_statements_cache=true") do |connection|
        before = connection.statement_cache_spec_size
        10.times do |value|
          Lustra::SQL.select("#{value} AS value").use_connection(NAME).scalar(Int32).should eq(value)
        end
        connection.statement_cache_spec_size.should eq(before + 10)

        Lustra::SQL.select("0 AS value").use_connection(NAME).scalar(Int32).should eq(0)
        connection.statement_cache_spec_size.should eq(before + 10)
      end
    end

    it "honors explicit cache disabling alongside other connection options" do
      with_pool("?max_pool_size=1&prepared_statements_cache=false") do |connection|
        before = connection.statement_cache_spec_size
        10.times do |value|
          Lustra::SQL.select("#{value} AS value").use_connection(NAME).scalar(Int32).should eq(value)
        end

        connection.statement_cache_spec_size.should eq(before)
      end
    end
  end
end
