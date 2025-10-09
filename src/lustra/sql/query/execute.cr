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
end
