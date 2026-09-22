require "../spec_helper"

class Lustra::SQL::ConnectionPool
  # Read only after all parallel workers have finished.
  def self.parallel_spec_state(name : String)
    {@@checkouts[name], @@connections.keys.count { |key| key[0] == name }}
  end

  def self.cleanup_parallel_spec(name : String)
    @@databases.delete(name).try(&.close)
    @@checkouts.delete(name)
    @@connections.reject! { |key, _connection| key[0] == name }
  end
end

module ParallelExecutionSpec
  WORKERS = 8
  URL     = "postgres://#{postgres_user}:#{postgres_password}@#{postgres_host}/lustra_spec"

  # Workers report failures to the spec fiber instead of losing exceptions in
  # detached fibers. The start gate lets them contend for the same pool.
  def self.run_workers(&block : Int32 -> Nil)
    context = Fiber::ExecutionContext::Parallel.new("lustra-spec", maximum: WORKERS)
    start = Channel(Nil).new
    finished = Channel(Exception?).new(WORKERS)
    WORKERS.times do |worker|
      context.spawn do
        failure = nil.as(Exception?)
        begin
          start.receive
          block.call(worker)
        rescue e
          failure = e
        ensure
          finished.send(failure)
        end
      end
    end
    WORKERS.times { start.send(nil) }
    failures = [] of Exception
    WORKERS.times do
      select
      when failure = finished.receive
        failures << failure if failure
      when timeout(30.seconds)
        raise "Parallel database workers did not finish within 30 seconds"
      end
    end
    failures.should be_empty
  end

  def self.with_pool(name : String, &)
    Lustra::SQL.init(name, URL + "?initial_pool_size=8&max_pool_size=8&max_idle_pool_size=8")
    yield
  ensure
    Lustra::SQL::ConnectionPool.cleanup_parallel_spec(name)
  end

  describe "Parallel execution contexts" do
    it "preserves nested connection ownership and clears all checkout state" do
      name = "parallel_checkout_spec"
      with_pool(name) do
        run_workers do |_worker|
          2_000.times do
            Lustra::SQL::ConnectionPool.with_connection(name) do |outer|
              Fiber.yield
              Lustra::SQL::ConnectionPool.with_connection(name) do |inner|
                raise "Nested checkout changed connections" unless inner.same?(outer)
              end
            end
          end
        end

        Lustra::SQL::ConnectionPool.parallel_spec_state(name).should eq({0, 0})
        # Leaked checkout counts must not prevent replacing an idle pool.
        Lustra::SQL.init(name, URL)
      end
    end

    it "runs only the committed callbacks belonging to each parallel transaction" do
      name = "parallel_callback_spec"
      with_pool(name) do
        run_workers do |worker|
          100.times do |iteration|
            callbacks = [] of String
            token = "#{worker}:#{iteration}"
            Lustra::SQL.transaction(name) do |outer|
              Lustra::SQL.after_commit(name) { callbacks << token }
              Lustra::SQL.with_savepoint(connection_name: name) do
                Lustra::SQL.after_commit(name) { callbacks << "rolled back" }
                Lustra::SQL.rollback
              end
              Lustra::SQL.with_savepoint(connection_name: name) do
                Lustra::SQL.after_commit(name) { callbacks << "released" }
              end
              Lustra::SQL.transaction(name) do |inner|
                raise "Nested transaction changed connections" unless inner.same?(outer)
              end
            end
            unless callbacks == [token, "released"]
              raise "Unexpected callbacks for #{token}: #{callbacks.inspect}"
            end
          end
        end
        Lustra::SQL::ConnectionPool.parallel_spec_state(name).should eq({0, 0})
      end
    end
  end
end
