require "../spec_helper"
require "../data/example_models"

module SaveRollbackSpec
  def self.fail_next_create(employee : Employee, &)
    fail_next = true
    callback = ->(model : Lustra::Model) do
      if model.same?(employee) && fail_next
        fail_next = false
        raise "after_create failed"
      end
      nil
    end
    Employee.after(:create, &callback)
    yield
  ensure
    Lustra::Model::EventManager::EVENT_CALLBACKS[{Employee.name, :after, :create}]?.try(&.delete(callback))
  end

  describe "model state after a save callback rolls back" do
    # Avoid `temporary`: save must own the transaction that gets rolled back.
    it "keeps a new record unpersisted when its insert is rolled back" do
      Lustra::SQL.execute("CREATE TABLE employees (id serial PRIMARY KEY, name text NOT NULL)")
      employee = Employee.new({name: "Original"})
      employee.name = "John"

      fail_next_create(employee) do
        expect_raises(Exception, "after_create failed") { employee.save! }

        Employee.query.count.should eq(0)
        employee.persisted?.should be_false
        employee.id_column.defined?.should be_false
        employee.name.should eq("John")
        employee.name_column.changed?.should be_true
        employee.name_column.old_value.should eq("Original")
      end
    ensure
      Lustra::SQL.execute("DROP TABLE employees")
    end

    it "inserts a new record when retrying a rolled-back save" do
      Lustra::SQL.execute("CREATE TABLE employees (id serial PRIMARY KEY, name text NOT NULL)")
      employee = Employee.new({name: "John"})

      fail_next_create(employee) do
        expect_raises(Exception, "after_create failed") { employee.save! }
        Employee.query.count.should eq(0)

        employee.save!

        Employee.query.count.should eq(1)
        Employee.find!(employee.id).name.should eq("John")
      end
    ensure
      Lustra::SQL.execute("DROP TABLE employees")
    end
  end
end
