require "../../spec_helper"

module LockSpec
  extend self

  describe Lustra::SQL::Query::Lock do
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
