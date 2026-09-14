class Lustra::SQL::ConnectionPool
  @@databases = {} of String => DB::Database

  @@connections = {} of {String, Fiber} => DB::Connection
  @@checkouts = Hash(String, Int32).new(0)

  def self.init(uri, name)
    name = name.to_s
    ensure_idle(name)
    connection_uri = URI.parse(uri.to_s)
    params = HTTP::Params.parse(connection_uri.query || "")
    # Literal SQL values produce distinct cache keys on long-lived connections.
    unless params.has_key?("prepared_statements_cache")
      params["prepared_statements_cache"] = "false"
      connection_uri.query = params.to_s
    end
    replacement = DB.open(connection_uri)
    begin
      # Opening the replacement can yield to a fiber using the existing pool.
      ensure_idle(name)
    rescue e
      replacement.close
      raise e
    end
    previous = @@databases[name]?
    @@databases[name] = replacement
    previous.try(&.close)
    replacement
  end

  private def self.ensure_idle(name : String)
    if @@checkouts[name] > 0
      raise Lustra::SQL::Error.new("Cannot replace connection pool '#{name}' while connections are in use")
    end
  end

  # Retrieve a connection from the connection pool, or wait for it.
  # If the current Fiber already has a connection, the connection is returned;
  #   this strategy provides easy usage of multiple statement connection (like BEGIN/ROLLBACK features).
  def self.with_connection(target : String, &)
    fiber_target = {target, Fiber.current}

    database = @@databases.fetch(target) { raise Lustra::ErrorMessages.uninitialized_db_connection(target) }

    if connection = @@connections[fiber_target]?
      return yield connection
    end

    # Retry acquisition only. Replaying the caller's block could repeat writes
    # or application side effects, including an entire transaction body.
    @@checkouts[target] += 1
    begin
      connection = database.retry { database.checkout }
      begin
        @@connections[fiber_target] = connection
        yield connection
      ensure
        @@connections.delete(fiber_target)
        connection.release
      end
    ensure
      @@checkouts[target] -= 1
      @@checkouts.delete(target) if @@checkouts[target] == 0
    end
  end
end
