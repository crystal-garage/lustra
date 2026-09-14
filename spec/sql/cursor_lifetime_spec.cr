require "../spec_helper"

module CursorLifetimeSpec
  def self.cursor_names(connection : DB::Connection)
    connection.query_all("SELECT name FROM pg_cursors WHERE name LIKE '__cursor_%' ORDER BY name", as: String)
  end

  describe "Cursor resource lifetime" do
    {"default", "secondary"}.each do |connection_name|
      it "closes a completed cursor inside an outer transaction on #{connection_name}" do
        Lustra::SQL.transaction(connection_name) do |connection|
          before = cursor_names(connection)
          values = [] of Int32
          Lustra::SQL.select("generate_series(1, 3) AS value").use_connection(connection_name).fetch_with_cursor(2) do |row|
            values << row["value"].as(Int32)
          end

          values.should eq([1, 2, 3])
          cursor_names(connection).should eq(before)
        end
      end

      it "closes a cursor after early exit on #{connection_name}" do
        Lustra::SQL.transaction(connection_name) do |connection|
          before = cursor_names(connection)
          calls = 0
          Lustra::SQL.select("generate_series(1, 3) AS value").use_connection(connection_name).fetch_with_cursor(1) do |_row|
            calls += 1
            break
          end

          calls.should eq(1)
          cursor_names(connection).should eq(before)
        end
      end

      it "closes a cursor while preserving a callback exception on #{connection_name}" do
        Lustra::SQL.transaction(connection_name) do |connection|
          before = cursor_names(connection)
          original = Exception.new("cursor callback failed")
          caught = expect_raises(Exception, "cursor callback failed") do
            Lustra::SQL.select("generate_series(1, 3) AS value").use_connection(connection_name).fetch_with_cursor(1) do |_row|
              raise original
            end
          end

          caught.should be(original)
          cursor_names(connection).should eq(before)
        end
      end
    end

    {0, -1}.each do |batch|
      it "rejects batch size #{batch} before query hooks or database work" do
        hook_calls = 0
        query = Lustra::SQL.select("1 AS value").before_query { hook_calls += 1 }

        expect_raises(ArgumentError, /positive/) do
          query.fetch_with_cursor(batch) { |_row| }
        end
        hook_calls.should eq(0)
      end
    end

    it "preserves the query error when cursor cleanup encounters an aborted transaction" do
      caught = expect_raises(Lustra::SQL::Error, /division by zero/) do
        Lustra::SQL.select("1 AS value").fetch_with_cursor(1) do |_row|
          Lustra::SQL.execute("SELECT 1 / 0")
        end
      end

      caught.cause.should be_a(PQ::PQError)
      Lustra::SQL.in_transaction?.should be_false
      Lustra::SQL.select("1").scalar(Int32).should eq(1)
    end

    it "preserves connection loss during cursor iteration" do
      caught = nil.as(DB::ConnectionLost?)
      raised = expect_raises(DB::ConnectionLost) do
        Lustra::SQL.select("1 AS value").fetch_with_cursor(1) do |_row|
          Lustra::SQL::ConnectionPool.with_connection("default") do |connection|
            failure = DB::ConnectionLost.new(connection)
            caught = failure
            raise failure
          end
        end
      end

      raised.should be(caught)
      Lustra::SQL.in_transaction?.should be_false
      Lustra::SQL.select("1").scalar(Int32).should eq(1)
    end
  end
end
