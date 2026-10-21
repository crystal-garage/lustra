module Lustra::SQL::Query::Pluck
  # Ask PostgreSQL for native output names and wildcard column order without
  # executing the query, so inspecting projections cannot run modifying CTEs.
  # :nodoc:
  class ProjectionStatement < PG::Statement
    # Describe without sending Execute: CTEs and expressions must not run here.
    def column_names : Array(String)
      protocol = conn
      protocol.send_parse_message(command)
      protocol.send_bind_message([] of PQ::Param)
      protocol.send_describe_portal_message
      protocol.send_sync_message
      protocol.expect_frame(PQ::Frame::ParseComplete)
      protocol.expect_frame(PQ::Frame::BindComplete)
      fields = protocol.expect_frame(PQ::Frame::RowDescription).fields
      protocol.expect_frame(PQ::Frame::ReadyForQuery)
      fields.map(&.name)
    rescue exception : IO::Error
      raise DB::ConnectionLost.new(connection, cause: exception)
    end
  end

  # Select a specific column of your SQL query, execute the query
  # and return an array containing this field.
  #
  # ```
  # User.query.pluck_col("id") # [1,2,3,4...]
  # ```
  #
  # Note: It returns an array of `Lustra::SQL::Any`. Therefore, you may want to use `pluck_col(str, Type)` to return
  #       an array of `Type`:
  #
  # ```
  # User.query.pluck_col("id", Int64)
  # ```
  #
  # The field argument is a SQL fragment; it's not escaped (beware SQL injection) and allow call to functions
  # and aggregate methods:
  #
  # ```
  # # ...
  # User.query.pluck_col("CASE WHEN id % 2 = 0 THEN id ELSE NULL END AS id").each do
  # # ...
  # ```
  def pluck_col(field : Lustra::SQL::Symbolic) : Array(Lustra::SQL::Any)
    field = Lustra::SQL.escape(field) if field.is_a?(Symbol)

    pluck_rows({field}) { |rs| rs.read.as(Lustra::SQL::Any) }
  end

  # :ditto:
  def pluck_col(field : Lustra::SQL::Symbolic, type : T.class) : Array(T) forall T
    field = Lustra::SQL.escape(field) if field.is_a?(Symbol)

    pluck_rows({field}, &.read(T))
  end

  # Select specifics columns and return an array of Tuple(*Lustra::SQL::Any) containing the columns in the order of the selected
  # arguments:
  #
  # ```
  # User.query.pluck("first_name", "last_name").each do |(first_name, last_name)|
  #   # ...
  # end
  # ```
  def pluck(*fields) : Array
    pluck(fields)
  end

  # :ditto:
  def pluck(fields : Tuple(*T)) forall T
    selections = fields.map { |f| f.is_a?(Symbol) ? Lustra::SQL.escape(f) : f.to_s }
    pluck_rows(selections) do |rs|
      {% begin %}
        { {% for t in T %} rs.read.as(Lustra::SQL::Any), {% end %} }
      {% end %}
    end
  end

  # Select specifics columns and returns on array of tuple of type of the named tuple passed as parameter:
  #
  # ```
  # User.query.pluck(id: Int64, "UPPER(last_name)": String).each do #...
  # ```
  def pluck(**fields : **T) forall T
    pluck_rows(fields.keys.map(&.to_s)) do |rs|
      {% begin %}
        { {% for k, v in T %} rs.read({{ v.instance }}), {% end %} }
      {% end %}
    end
  end

  private def pluck_rows(fields, & : DB::ResultSet -> T) : Array(T) forall T
    sql = pluck_sql(fields)

    Lustra::SQL::ConnectionPool.with_connection(connection_name) do |cnx|
      rs = Lustra::SQL.log_query(sql) { cnx.query(sql) }

      o = [] of T

      while rs.move_next
        o << yield rs
      end
      o
    ensure
      rs.try &.close
    end
  end

  private def pluck_sql(fields) : String
    dup.clear_before_query_triggers.clear_select.select(fields.join(", ")).to_sql
  end
end
