require "../spec_helper"

module CounterSafetySpec
  class Parent
    include Lustra::Model

    self.table = "counter_safety_parents"

    column id : String, primary: true
    column children_count : Int32, presence: false
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

  def self.create_tables
    Lustra::SQL.execute(<<-SQL)
      CREATE TABLE counter_safety_parents (
        id text PRIMARY KEY,
        children_count integer NOT NULL DEFAULT 0
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
