require "../spec_helper"

module SQLMiscSpec
  extend self

  @@count = 0_i64

  def self.reinit
    reinit_migration_manager
  end

  describe "Lustra::SQL" do
    describe "miscalleanous" do
      it "escape for SQL-safe object" do
        Lustra::SQL.escape("order").should eq "\"order\""
        Lustra::SQL.escape("").should eq "\"\""
        Lustra::SQL.escape(:hello).should eq "\"hello\""

        Lustra::SQL.escape("some.weird.column name").should eq "\"some.weird.column name\""
        Lustra::SQL.escape("\"hello world\"").should eq "\"\"\"hello world\"\"\""
      end

      it "sanitize for SQL-safe string" do
        Lustra::SQL.sanitize(1).should eq "1"
        Lustra::SQL.sanitize("").should eq "''"
        Lustra::SQL.sanitize(nil).should eq "NULL"
        Lustra::SQL.sanitize("l'hotel").should eq "'l''hotel'"
      end

      it "create SQL fragment" do
        Lustra::SQL.raw("SELECT * FROM table WHERE x = ?", "hello").should eq(
          %(SELECT * FROM table WHERE x = 'hello')
        )

        Lustra::SQL.raw("SELECT * FROM table WHERE x = :x", x: 1).should eq(
          %(SELECT * FROM table WHERE x = 1)
        )
      end

      it "truncate a table" do
        begin
          Lustra::SQL.execute("CREATE TABLE truncate_tests (id serial PRIMARY KEY, value int)")

          5.times do |x|
            Lustra::SQL.insert("truncate_tests", {value: x}).execute
          end

          count = Lustra::SQL.select.from("truncate_tests").count
          count.should eq 5

          # Truncate the table
          Lustra::SQL.truncate("truncate_tests")
          count = Lustra::SQL.select.from("truncate_tests").count
          count.should eq 0
        ensure
          Lustra::SQL.execute("DROP TABLE truncate_tests;")
        end
      end
    end
  end
end
