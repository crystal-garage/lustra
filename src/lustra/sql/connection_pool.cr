class Lustra::SQL::ConnectionPool
  @@databases = {} of String => DB::Database

  @@connections = {} of {String, Fiber} => DB::Connection

  def self.init(uri, name)
    @@databases[name] = DB.open(uri)
  end

  # Retrieve a connection from the connection pool, or wait for it.
  # If the current Fiber already has a connection, the connection is returned;
  #   this strategy provides easy usage of multiple statement connection (like BEGIN/ROLLBACK features).
  def self.with_connection(target : String, &)
    fiber_target = {target, Fiber.current}

    database = @@databases.fetch(target) { raise Lustra::ErrorMessages.uninitialized_db_connection(target) }

    database.retry do
      connection = @@connections[fiber_target]?

      if connection
        begin
          yield connection
        rescue ex : DB::ConnectionLost
          # Remove the cached (lost) connection so the retry can obtain a fresh one
          @@connections.delete(fiber_target)

          # Re-raise the original exception
          raise ex
        end
      else
        database.using_connection do |new_connection|
          @@connections[fiber_target] = new_connection

          yield new_connection
        ensure
          @@connections.delete(fiber_target)
        end
      end
    end
  end
end
