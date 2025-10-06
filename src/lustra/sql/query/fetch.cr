module Lustra::SQL::Query::Fetch
  # :no_doc:
  protected def fetch_result_set(h : Hash(String, ::Lustra::SQL::Any), rs, &) : Bool
    return false unless rs.move_next

    loop do
      rs.each_column do |col|
        h[col] = rs.read.as(Lustra::SQL::Any)
      end

      yield(h)

      break unless rs.move_next
    end

    true
  ensure
    rs.close
  end

  # Fetch the data using CURSOR.
  # This will prevent Lustra to load all the data from the database into memory.
  # This is useful if you need to retrieve and update a large dataset.
  def fetch_with_cursor(count = 1_000, & : Hash(String, ::Lustra::SQL::Any) -> Nil)
    trigger_before_query

    Lustra::SQL.transaction do |cnx|
      cursor_name = "__cursor_#{Time.local.to_unix ^ (rand * 0xfffffff).to_i}__"

      cursor_declaration = "DECLARE #{cursor_name} CURSOR FOR #{to_sql}"

      Lustra::SQL.log_query(cursor_declaration) { cnx.exec(cursor_declaration) }

      h = {} of String => ::Lustra::SQL::Any

      we_loop = true

      while we_loop
        fetch_query = "FETCH #{count} FROM #{cursor_name}"

        rs = Lustra::SQL.log_query(fetch_query) { cnx.query(fetch_query) }

        o = Array(Hash(String, ::Lustra::SQL::Any)).new(initial_capacity: count)

        we_loop = fetch_result_set(h, rs) { |x| o << x.dup }

        o.each { |hash| yield(hash) }
      end
    end
  end

  # Helpers to fetch a SELECT with only one row and one column return.
  def scalar(type : T.class) forall T
    trigger_before_query

    sql = to_sql

    Lustra::SQL.log_query sql do
      Lustra::SQL::ConnectionPool.with_connection(connection_name, &.scalar(sql)).as(T)
    end
  end

  # Return the first line of the query as Hash(String, ::Lustra::SQL::Any), or nil
  # if not found
  def first
    fetch_first
  end

  def first!
    fetch_first!
  end

  # Alias for `first` because first is redefined in Collection::Base
  # object to return a model instead.
  def fetch_first
    limit(1).fetch(fetch_all: true) { |x| return x }

    nil
  end

  def fetch_first!
    if o = fetch_first
      o
    else
      raise Lustra::SQL::RecordNotFoundError.new
    end
  end

  # Return an array with all the rows fetched.
  def to_a : Array(Hash(String, ::Lustra::SQL::Any))
    trigger_before_query

    h = {} of String => ::Lustra::SQL::Any

    sql = to_sql

    rs = Lustra::SQL.log_query(sql) { Lustra::SQL::ConnectionPool.with_connection(connection_name, &.query(sql)) }

    o = [] of Hash(String, ::Lustra::SQL::Any)
    fetch_result_set(h, rs) { |x| o << x.dup }

    o
  end

  # Fetch the result set row per row
  # `fetch_all` optional parameter is helpful in transactional environment, so it stores
  # the result and close the resultset before starting to call yield over the data
  # preventing creation of a new connection if you need to call SQL into the
  # yielded block.
  #
  # ```
  # # This is wrong: The connection is still busy retrieving the users:
  # Lustra::SQL.select.from("users").fetch do |u|
  #   Lustra::SQL.select.from("posts").where { u["id"] == posts.id }
  # end
  #
  # # Instead, use `fetch_all`
  # # Lustra will store the value of the result set in memory
  # # before calling the block, and the connection is now ready to handle
  # # another query.
  # Lustra::SQL.select.from("users").fetch(fetch_all: true) do |u|
  #   Lustra::SQL.select.from("posts").where { u["id"] == posts.id }
  # end
  # ```
  def fetch(fetch_all = false, & : Hash(String, ::Lustra::SQL::Any) -> Nil)
    trigger_before_query

    h = {} of String => ::Lustra::SQL::Any

    sql = to_sql

    Lustra::SQL::ConnectionPool.with_connection(connection_name) do |cnx|
      rs = Lustra::SQL.log_query(sql) { cnx.query(sql) }

      if fetch_all
        o = [] of Hash(String, ::Lustra::SQL::Any)
        fetch_result_set(h, rs) { |x| o << x.dup }
        o.each { |x| yield(x) }
      else
        fetch_result_set(h, rs) { |x| yield(x) }
      end
    end
  end
end
