require "db"

module Lustra::SQL::Query::Execute
  #
  # Execute an SQL statement which does not return anything.
  #
  # If an optional `connection_name` parameter is given, this will
  #   override the connection used by the query.
  #
  # ```
  # %(default secondary).each do |cnx|
  #   Lustra::SQL.select("pg_shards('xxx')").execute(cnx)
  # end
  # ```
  def execute(connection_name : String? = nil)
    Lustra::SQL.execute(connection_name || self.connection_name, to_sql)
  end

  # Run the query and return the number of rows affected.
  # This is useful for UPDATE and DELETE queries.
  #
  # ```
  # affected = User.query.where { active == false }.to_update.set(active: true).execute_and_count
  # puts "Updated #{affected} rows"
  # ```
  def execute_and_count(connection_name : String? = nil) : Int64
    sql = to_sql
    Lustra::SQL.log_query(sql) do
      Lustra::SQL::ConnectionPool.with_connection(connection_name || self.connection_name) do |cnx|
        cnx.exec(sql).rows_affected
      end
    end
  end

  # Returns the PostgreSQL query execution plan.
  # Shows the execution plan without running the actual query (for SELECT),
  # but for INSERT/UPDATE/DELETE it shows the plan without modifying data.
  #
  # ```
  # plan = User.query.where { active == true }.explain
  # puts plan
  # # => "Seq Scan on users  (cost=0.00..35.50 rows=10 width=116)"
  # ```
  #
  # Returns the full EXPLAIN output as a string.
  def explain(connection_name : String? = nil) : String
    sql = "EXPLAIN #{to_sql}"
    result = [] of String

    Lustra::SQL.log_query(sql) do
      Lustra::SQL::ConnectionPool.with_connection(connection_name || self.connection_name) do |cnx|
        cnx.query(sql) do |rs|
          rs.each do
            result << rs.read(String)
          end
        end
      end
    end

    result.join("\n")
  end

  # Returns the PostgreSQL query execution plan AND executes the query to get actual statistics.
  # This shows actual execution times, row counts, and resource usage.
  #
  # ```
  # plan = User.query.where { active == true }.explain_analyze
  # puts plan
  # # Shows actual execution time, rows processed, and detailed statistics
  # ```
  #
  # **Warning:** This EXECUTES the query (including INSERT/UPDATE/DELETE).
  # Use with caution on write operations. Wrap in a transaction and rollback if needed.
  #
  # Returns the full EXPLAIN ANALYZE output as a string.
  def explain_analyze(connection_name : String? = nil) : String
    sql = "EXPLAIN ANALYZE #{to_sql}"
    result = [] of String

    Lustra::SQL.log_query(sql) do
      Lustra::SQL::ConnectionPool.with_connection(connection_name || self.connection_name) do |cnx|
        cnx.query(sql) do |rs|
          rs.each do
            result << rs.read(String)
          end
        end
      end
    end

    result.join("\n")
  end
end
