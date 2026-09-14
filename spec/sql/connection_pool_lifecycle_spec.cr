require "../spec_helper"

class Lustra::SQL::ConnectionPool
  # Spec-only cleanup until Lustra exposes pool shutdown.
  def self.cleanup_lifecycle_spec(name : String)
    @@databases.delete(name).try(&.close)
  end

  def self.lifecycle_spec_database(name : String)
    @@databases[name]
  end
end

module ConnectionPoolLifecycleSpec
  NAME = "pool_lifecycle_spec"
  URL  = "postgres://#{postgres_user}:#{postgres_password}@#{postgres_host}/lustra_spec"

  def self.with_pool(&)
    Lustra::SQL.init(NAME, URL)
    yield
  ensure
    Lustra::SQL::ConnectionPool.cleanup_lifecycle_spec(NAME)
  end

  describe "Connection pool lifecycle" do
    it "preserves the existing pool if opening the replacement fails" do
      with_pool do
        previous = Lustra::SQL::ConnectionPool.with_connection(NAME) { |connection| connection }
        expect_raises(ArgumentError, /no driver was registered/) do
          Lustra::SQL.init(NAME, "unregistered-lifecycle-driver://localhost/database")
        end
        previous.closed?.should be_false
        Lustra::SQL::ConnectionPool.with_connection(NAME) do |connection|
          connection.should be(previous)
          connection.query_one("SELECT 1", as: Int32).should eq(1)
        end
      end
    end

    it "rejects replacement while a connection is still being acquired" do
      with_pool do
        Lustra::SQL.init(NAME, URL + "?initial_pool_size=0")
        acquiring = Channel(Nil).new
        resume = Channel(Nil).new
        finished = Channel(Exception?).new
        database = Lustra::SQL::ConnectionPool.lifecycle_spec_database(NAME)
        database.setup_connection do |_connection|
          acquiring.send(nil)
          resume.receive
        end

        spawn do
          failure = nil.as(Exception?)
          begin
            Lustra::SQL::ConnectionPool.with_connection(NAME) do |connection|
              connection.query_one("SELECT 1", as: Int32).should eq(1)
            end
          rescue e
            failure = e
          ensure
            finished.send(failure)
          end
        end

        acquiring.receive
        begin
          expect_raises(Lustra::SQL::Error, /while connections are in use/) do
            Lustra::SQL.init(NAME, URL)
          end
        ensure
          resume.send(nil)
          finished.receive.should be_nil
        end

        # Once checkout has finished, the same name can be replaced normally.
        Lustra::SQL.init(NAME, URL)
      end
    end

    it "closes the previous idle pool when replacing a connection name" do
      with_pool do
        previous = Lustra::SQL::ConnectionPool.with_connection(NAME) { |connection| connection }
        begin
          Lustra::SQL.init(NAME, URL)

          previous.closed?.should be_true
          Lustra::SQL::ConnectionPool.with_connection(NAME) do |connection|
            connection.should_not be(previous)
            connection.query_one("SELECT 1", as: Int32).should eq(1)
          end
        ensure
          # Close the orphan left by the current implementation, even on failure.
          previous.close
        end
      end
    end

    it "rejects replacement while the current fiber has a checked-out connection" do
      with_pool do
        Lustra::SQL::ConnectionPool.with_connection(NAME) do |connection|
          expect_raises(Lustra::SQL::Error) do
            Lustra::SQL.init(NAME, URL)
          end

          connection.closed?.should be_false
          connection.query_one("SELECT 1", as: Int32).should eq(1)
        ensure
          connection.close
        end
      end
    end

    it "rejects replacement while another fiber has a checked-out connection" do
      with_pool do
        acquired = Channel(DB::Connection).new
        release = Channel(Nil).new
        finished = Channel(Nil).new

        spawn do
          Lustra::SQL::ConnectionPool.with_connection(NAME) do |connection|
            acquired.send(connection)
            release.receive
          ensure
            connection.close
          end
        ensure
          finished.send(nil)
        end

        connection = acquired.receive
        begin
          expect_raises(Lustra::SQL::Error) do
            Lustra::SQL.init(NAME, URL)
          end
          connection.closed?.should be_false
        ensure
          release.send(nil)
          finished.receive
        end
      end
    end
  end
end
