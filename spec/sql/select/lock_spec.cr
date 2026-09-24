require "../../spec_helper"

module LockSpec
  extend self

  describe Lustra::SQL::Query::Lock do
    it "does not lock rows by default" do
      query = Lustra::SQL.select.from(:users)

      query.lock.should be_nil
      query.to_sql.should eq("SELECT * FROM \"users\"")
    end

    it "appends FOR UPDATE after ordering and pagination" do
      query = Lustra::SQL.select.from(:users).order_by(:id).limit(2).offset(1)

      query.with_lock.should be(query)
      query.lock.should eq("FOR UPDATE")
      query.to_sql.should eq("SELECT * FROM \"users\" ORDER BY \"id\" ASC LIMIT 2 OFFSET 1 FOR UPDATE")
    end

    {"FOR NO KEY UPDATE", "FOR SHARE", "FOR KEY SHARE", "FOR UPDATE NOWAIT", "FOR UPDATE SKIP LOCKED", "FOR UPDATE OF users"}.each do |clause|
      it "supports #{clause}" do
        query = Lustra::SQL.select.from(:users).with_lock(clause)

        query.lock.should eq(clause)
        query.to_sql.should eq("SELECT * FROM \"users\" #{clause}")
      end
    end

    it "preserves the lock on duplication and replaces it independently" do
      original = Lustra::SQL.select.from(:users).with_lock
      copy = original.dup

      copy.lock.should eq("FOR UPDATE")
      copy.to_sql.should eq(original.to_sql)
      copy.with_lock("FOR SHARE")

      copy.to_sql.should eq("SELECT * FROM \"users\" FOR SHARE")
      original.to_sql.should eq("SELECT * FROM \"users\" FOR UPDATE")
    end

    it "locks selected rows until the transaction ends" do
      Lustra::SQL.execute("CREATE TABLE row_lock_spec (id integer PRIMARY KEY)")
      Lustra::SQL.insert(:row_lock_spec, [{id: 1}, {id: 2}]).execute

      DB.open("postgres://#{postgres_user}:#{postgres_password}@#{postgres_host}/lustra_spec") do |other|
        locked_row = Lustra::SQL.select(:id).from(:row_lock_spec).where(id: 1).with_lock("FOR UPDATE NOWAIT")
        available_rows = Lustra::SQL.select(:id).from(:row_lock_spec).order_by(:id).with_lock("FOR UPDATE SKIP LOCKED")

        Lustra::SQL.transaction do
          Lustra::SQL.select.from(:row_lock_spec).where(id: 1).with_lock.to_a.size.should eq(1)

          expect_raises(PQ::PQError, /could not obtain lock on row/) do
            other.query_all(locked_row.to_sql, as: Int32)
          end
          other.query_all(available_rows.to_sql, as: Int32).should eq([2])
        end

        other.query_all(locked_row.to_sql, as: Int32).should eq([1])
        other.query_all(available_rows.to_sql, as: Int32).should eq([1, 2])
      end
    ensure
      Lustra::SQL.execute("DROP TABLE IF EXISTS row_lock_spec")
    end

    it "lock a table" do
      # ! We can't use transactional block here because we're testing behavior between different connections
      Lustra::SQL.execute("CREATE TABLE to_lock ( id serial NOT NULL )")
      Lustra::SQL.insert("to_lock", {id: 1}).execute

      Lustra::SQL.lock("to_lock") do
        spawn do
          # Fiber using another connection, should hang...
          Lustra::SQL.insert("to_lock", {id: 2}).execute
        end

        10.times { Fiber.yield } # Ensure the new fiber is started...
        Lustra::SQL.select.from(:to_lock).pluck_col(:id).should eq [1]
      end

      sleep(50.milliseconds) # Give hand to the other fiber. Now it should be not locked anymore?
      Lustra::SQL.select.from(:to_lock).order_by("id", :asc).pluck_col(:id).should eq [1, 2]
    ensure
      Lustra::SQL.execute("DROP TABLE to_lock")
    end
  end
end
