require "sync/mutex"

class Lustra::SQL::ConnectionPool
  @@databases = {} of String => DB::Database

  @@connections = {} of {String, Fiber} => DB::Connection
  @@checkouts = Hash(String, Int32).new(0)
  @@mutex = Sync::Mutex.new

  def self.init(uri, name)
    name = name.to_s
    @@mutex.synchronize { ensure_idle(name) }
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
      previous = @@mutex.synchronize do
        ensure_idle(name)
        old = @@databases[name]?
        @@databases[name] = replacement
        old
      end
    rescue e
      replacement.close
      raise e
    end
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

    # Reserve the pool before releasing the lock so init cannot replace it
    # between lookup and checkout. Never hold this lock during database I/O.
    database, existing = @@mutex.synchronize do
      pool = @@databases.fetch(target) { raise Lustra::ErrorMessages.uninitialized_db_connection(target) }
      cached = @@connections[fiber_target]?
      @@checkouts[target] += 1 unless cached
      {pool, cached}
    end

    return yield existing if existing

    # Retry acquisition only. Replaying the caller's block could repeat writes
    # or application side effects, including an entire transaction body.
    begin
      connection = database.retry { database.checkout }
      begin
        @@mutex.synchronize { @@connections[fiber_target] = connection }
        yield connection
      ensure
        @@mutex.synchronize { @@connections.delete(fiber_target) }
        connection.release
      end
    ensure
      @@mutex.synchronize do
        @@checkouts[target] -= 1
        @@checkouts.delete(target) if @@checkouts[target] == 0
      end
    end
  end
end
