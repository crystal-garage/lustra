require "../spec_helper"

module CounterSafetySpec
  QUERIES = {} of Fiber => Array(String)

  def self.capture_queries(&)
    queries = [] of String
    QUERIES[Fiber.current] = queries
    yield
    queries
  ensure
    QUERIES.delete(Fiber.current)
  end

  class Parent
    include Lustra::Model

    self.table = "counter_safety_parents"

    column id : String, primary: true
    column children_count : Int32, presence: false
    column label : String?
  end

  class Child
    include Lustra::Model

    self.table = "counter_safety_children"

    column id : Int32, primary: true, presence: false

    belongs_to owner : Parent,
      foreign_key: "parent_id",
      foreign_key_type: String,
      counter_cache: :children_count
  end

  class SecondaryParent
    include Lustra::Model

    self.table = "counter_safety_parents"
    self.connection = "secondary"

    column id : String, primary: true
    column children_count : Int32, presence: false
  end

  def self.create_tables
    Lustra::SQL.execute(<<-SQL)
      CREATE TABLE counter_safety_parents (
        id text PRIMARY KEY,
        children_count integer NOT NULL DEFAULT 0,
        label text
      )
      SQL
    Lustra::SQL.execute(<<-SQL)
      CREATE TABLE counter_safety_children (
        id serial PRIMARY KEY,
        parent_id text NOT NULL
      )
      SQL
  end

  def self.drop_tables
    Lustra::SQL.execute("DROP TABLE IF EXISTS counter_safety_children")
    Lustra::SQL.execute("DROP TABLE IF EXISTS counter_safety_parents")
  end

  describe "counter helpers" do
    it "raises without changing local state when the persisted row no longer exists" do
      temporary do
        create_tables
        parent = Parent.create!(id: "deleted", children_count: 5)
        Parent.query.where(id: parent.id).delete_all
        parent.label = "Pending edit"

        expect_raises(Lustra::SQL::RecordNotFoundError) { parent.increment!(:children_count) }

        parent.children_count.should eq(5)
        parent.label_column.changed?.should be_true
      end
    end

    it "increments a quoted primary key in one statement and preserves pending edits" do
      temporary do
        create_tables
        parent = Parent.create!(id: "quoted'id", children_count: 0)

        parent.label = "Pending edit"
        # The persisted counter is the starting value, even with a local edit.
        parent.children_count = 10
        queries = capture_queries { parent.increment!(:children_count, 3) }

        parent.children_count.should eq(3)
        parent.label.should eq("Pending edit")
        parent.label_column.changed?.should be_true
        parent.children_count_column.changed?.should be_false
        Parent.find!("quoted'id").children_count.should eq(3)
        queries.size.should eq(1)
        queries.first.should match(/\AUPDATE .* RETURNING /)
      end
    end

    it "decrements a counter in one statement" do
      temporary do
        create_tables
        parent = Parent.create!(id: "quoted'id", children_count: 5)
        queries = capture_queries { parent.decrement!(:children_count, 2) }

        parent.children_count.should eq(3)
        Parent.find!("quoted'id").children_count.should eq(3)
        queries.size.should eq(1)
        queries.first.should match(/\AUPDATE .* RETURNING /)
      end
    end

    it "increments in one statement on the model's named connection" do
      Lustra::SQL.transaction("secondary") do
        Lustra::SQL.execute("secondary", "CREATE TABLE counter_safety_parents (id text PRIMARY KEY, children_count integer NOT NULL DEFAULT 0)")
        parent = SecondaryParent.create!(id: "quoted'id", children_count: 4)
        queries = capture_queries { parent.increment!(:children_count, 2) }

        parent.children_count.should eq(6)
        SecondaryParent.find!("quoted'id").children_count.should eq(6)
        queries.size.should eq(1)
        queries.first.should match(/\AUPDATE .* RETURNING /)
        Lustra::SQL.rollback
      end
    end

    it "increments a model with a quoted string primary key" do
      drop_tables
      create_tables

      begin
        parent = Parent.create!(id: "quoted'id", children_count: 0)
        parent.increment!(:children_count)

        parent.children_count.should eq(1)
        Parent.find!("quoted'id").children_count.should eq(1)
      ensure
        drop_tables
      end
    end

    it "resets counters for a quoted string primary key" do
      drop_tables
      create_tables

      begin
        parent = Parent.create!(id: "quoted'id", children_count: 0)
        Lustra::SQL.insert_into("counter_safety_children", {parent_id: parent.id}).execute

        parent.reset_counters(Child)

        parent.children_count.should eq(1)
        Parent.find!("quoted'id").children_count.should eq(1)
      ensure
        drop_tables
      end
    end

    it "updates counter caches for a quoted string primary key" do
      drop_tables
      create_tables

      begin
        parent = Parent.create!(id: "quoted'id", children_count: 0)
        Child.create!(owner: parent)

        parent.reload.children_count.should eq(1)
      ensure
        drop_tables
      end
    end
  end
end

module Lustra::SQL::Logger
  def log_query(sql, &)
    CounterSafetySpec::QUERIES[Fiber.current]?.try(&.push(sql.to_s))
    previous_def(sql) { yield }
  end
end
