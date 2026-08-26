module Lustra::SQL::Query::Returning
  def self.empty_result(_columns : T) forall T
    {% raise "returning expects a NamedTuple of column names and types" unless T < NamedTuple %}

    {% begin %}
      [] of Tuple({% for name, type in T %}{{ type.instance }},{% end %})
    {% end %}
  end

  macro included
    @returning : String? = nil
    getter returning
  end

  # Add a PostgreSQL `RETURNING` clause.
  # The SQL fragment is inserted directly and must not contain untrusted input.
  def returning(str : String)
    @returning = str

    change!
  end

  # Execute a statement with a `RETURNING` clause and yield each returned row.
  def fetch(connection_name : String? = nil, & : Hash(String, Lustra::SQL::Any) -> Nil)
    h = {} of String => Lustra::SQL::Any

    Lustra::SQL::ConnectionPool.with_connection(connection_name || self.connection_name) do |cnx|
      sql = to_sql
      rs = Lustra::SQL.log_query(sql) { cnx.query(sql) }

      while rs.move_next
        rs.each_column do |column|
          h[column] = rs.read.as(Lustra::SQL::Any)
        end

        yield(h)
      end
    ensure
      rs.try &.close
    end
  end

  # Execute a statement and return the requested columns as typed tuples.
  def execute_returning(columns : T, connection_name : String? = nil) forall T
    {% raise "execute_returning expects a NamedTuple of column names and types" unless T < NamedTuple %}

    returning(columns.keys.join(", ") { |column| Lustra::SQL.escape(column.to_s) })

    sql = to_sql

    Lustra::SQL::ConnectionPool.with_connection(connection_name || self.connection_name) do |cnx|
      rs = Lustra::SQL.log_query(sql) { cnx.query(sql) }

      {% begin %}
        result = [] of Tuple({% for name, type in T %}{{ type.instance }},{% end %})

        while rs.move_next
          result << { {% for name, type in T %}rs.read({{ type.instance }}),{% end %} }
        end

        result
      {% end %}
    ensure
      rs.try &.close
    end
  end

  # :nodoc:
  protected def append_returning(sql)
    if returning = @returning
      sql << "RETURNING"
      sql << returning
    end

    sql
  end
end
