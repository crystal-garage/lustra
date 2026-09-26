require "../spec_helper"
require "../data/example_models"

module AggregateSpec
  extend self

  describe "Lustra::SQL::Query::Aggregate" do
    it "does not find rows in a query limited to zero" do
      query = Lustra::SQL.select(:value)
        .from("(VALUES (10)) AS entries(value)").limit(0)

      query.to_a.should be_empty
      query.exists?.should be_false
    end

    it "aggregates a qualified field from its original table" do
      query = Lustra::SQL.select(:value)
        .from("(VALUES (10), (20), (30), (40)) AS entries(value)")

      query.to_a.map(&.["value"]).should eq([10, 20, 30, 40])
      query.sum("entries.value", Int64).should eq(100_i64)
      query.min("entries.value", Int32).should eq(10)
    end

    it "aggregates a qualified field after ordering and pagination" do
      query = Lustra::SQL.select(:value)
        .from("(VALUES (10), (20), (30), (40)) AS entries(value)")
        .order_by(:value, :desc).limit(2)

      query.to_a.map(&.["value"]).should eq([40, 30])
      query.sum("entries.value", Int64).should eq(70_i64)
      query.max("entries.value", Int32).should eq(40)
    end

    it "counts groups defined by a selected alias" do
      query = Lustra::SQL.select("value % 2 AS bucket")
        .from("(VALUES (1), (2), (3), (4)) AS entries(value)")
        .group_by(:bucket)

      query.to_a.size.should eq(2)
      query.count.should eq(2_i64)
    end

    it "counts groups defined by a selected column position" do
      query = Lustra::SQL.select(:id)
        .from("(VALUES (1), (1), (2), (2)) AS entries(id)")
        .group_by("1")

      query.to_a.size.should eq(2)
      query.count.should eq(2_i64)
    end

    it "counts the result rows of an aggregate selection" do
      query = Lustra::SQL.select("SUM(value) AS total")
        .from("(VALUES (10), (20), (30), (40)) AS entries(value)")

      query.to_a.should eq([{"total" => 100_i64}])
      query.count.should eq(1_i64)
    end

    it "aggregates the rows selected by ordering and a limit" do
      query = Lustra::SQL.select(:value)
        .from("(VALUES (10), (30), (20), (40)) AS entries(value)")
        .order_by(:value, :desc).limit(2)

      query.to_a.map(&.["value"]).should eq([40, 30])
      query.sum("value", Int64).should eq(70_i64)
      query.min("value", Int32).should eq(30)
      query.max("value", Int32).should eq(40)
      query.avg("value", PG::Numeric).to_f.should eq(35.0)
    end

    it "aggregates the rows remaining after ordering and an offset" do
      query = Lustra::SQL.select(:value)
        .from("(VALUES (10), (30), (20), (40)) AS entries(value)")
        .order_by(:value, :desc).offset(1)

      query.to_a.map(&.["value"]).should eq([30, 20, 10])
      query.sum("value", Int64).should eq(60_i64)
      query.min("value", Int32).should eq(10)
      query.max("value", Int32).should eq(30)
      query.avg("value", PG::Numeric).to_f.should eq(20.0)
    end

    it "aggregates the representatives selected by DISTINCT ON ordering" do
      query = Lustra::SQL.select(:id, :value)
        .from("(VALUES (1, 10), (1, 30), (2, 20), (2, 40)) AS entries(id, value)")
        .distinct("id").order_by(:id).order_by(:value, :desc)

      query.to_a.map(&.["value"]).should eq([30, 40])
      query.sum("value", Int64).should eq(70_i64)
      query.min("value", Int32).should eq(30)
      query.max("value", Int32).should eq(40)
      query.avg("value", PG::Numeric).to_f.should eq(35.0)
    end

    it "clears all grouping expressions without removing filters, ordering, or limits" do
      original = Lustra::SQL.select("SUM(value) AS total")
        .from("(VALUES ('a', 1), ('a', 2), ('b', 4), ('skip', 100)) AS entries(bucket, value)")
        .where { bucket != "skip" }.group_by(:bucket).group_by("value % 2")
        .order_by(:total, :desc).limit(2)

      original.to_a.map(&.["total"]).should eq([4_i64, 2_i64])
      cleared = original.dup.clear_group_bys
      cleared.to_a.map(&.["total"]).should eq([7_i64])
      original.to_a.map(&.["total"]).should eq([4_i64, 2_i64])

      cleared.group_by(:bucket).to_a.map(&.["total"]).should eq([4_i64, 3_i64])
    end

    it "does not run or consume eager-loading hooks for count" do
      temporary do
        reinit_example_models
        User.create!(first_name: "User")

        hook_called = false
        users = User.query.with_posts { hook_called = true }

        users.count.should eq(1)
        hook_called.should be_false

        users.each { }
        hook_called.should be_true
      end
    end

    it "does not run or consume eager-loading hooks for aggregates" do
      temporary do
        reinit_example_models
        User.create!(first_name: "User", posts_count: 2)

        hook_called = false
        users = User.query.with_posts { hook_called = true }

        users.sum("posts_count").should eq(2.0)
        hook_called.should be_false

        users.each { }
        hook_called.should be_true
      end
    end

    describe "#sum" do
      it "returns sum of integer field" do
        temporary do
          reinit_example_models

          User.create({first_name: "John", posts_count: 10})
          User.create({first_name: "Jane", posts_count: 20})
          User.create({first_name: "Bob", posts_count: 30})

          sum = User.query.sum("posts_count")
          sum.should eq 60.0
        end
      end

      it "returns 0.0 for empty result set" do
        temporary do
          reinit_example_models

          sum = User.query.sum("posts_count")
          sum.should eq 0.0
        end
      end

      it "returns the requested type" do
        temporary do
          reinit_example_models

          User.create({first_name: "John", posts_count: 10})
          User.create({first_name: "Jane", posts_count: 20})

          sum = User.query.sum("posts_count", Int64)
          sum.should be_a(Int64)
          sum.should eq 30_i64
        end
      end

      it "returns a typed zero for an empty result set" do
        temporary do
          reinit_example_models

          sum = User.query.sum("posts_count", Int64)
          sum.should be_a(Int64)
          sum.should eq 0_i64
        end
      end

      it "works with WHERE clause" do
        temporary do
          reinit_example_models

          User.create({first_name: "John", posts_count: -10})
          User.create({first_name: "Jane", posts_count: -20})
          User.create({first_name: "Bob", posts_count: 30})
          User.create({first_name: "Alice", posts_count: 40})

          query = User.query

          sum = query.dup.where { posts_count < 0 }.sum("posts_count")
          sum.should eq -30.0

          sum = query.dup.where { posts_count > 0 }.sum("posts_count")
          sum.should eq 70.0
        end
      end

      it "works with ORDER BY" do
        temporary do
          reinit_example_models

          User.create({first_name: "John", posts_count: 10})
          User.create({first_name: "Jane", posts_count: 20})
          User.create({first_name: "Bob", posts_count: 30})
          User.create({first_name: "Alice", posts_count: 40})

          sum = User.query.order_by(first_name: :desc).sum("posts_count")
          sum.should eq 100.0
        end
      end

      it "works with LIMIT and OFFSET" do
        temporary do
          reinit_example_models

          User.create({first_name: "John", posts_count: 10})
          User.create({first_name: "Jane", posts_count: 20})
          User.create({first_name: "Bob", posts_count: 30})
          User.create({first_name: "Alice", posts_count: 40})

          sum = User.query.limit(2).offset(1).sum("posts_count")
          sum.should eq 50.0
        end
      end

      it "handles zero values" do
        temporary do
          reinit_example_models

          User.create({first_name: "John", posts_count: 0})
          User.create({first_name: "Jane", posts_count: 20})
          User.create({first_name: "Bob", posts_count: 0})

          sum = User.query.sum("posts_count")
          sum.should eq 20.0
        end
      end
    end

    describe "#min" do
      it "returns minimum value" do
        temporary do
          reinit_example_models

          User.create({first_name: "John", posts_count: 30})
          User.create({first_name: "Jane", posts_count: 10})
          User.create({first_name: "Bob", posts_count: 20})

          min = User.query.min("posts_count", Int32)
          min.should eq 10
        end
      end
    end

    describe "#max" do
      it "returns maximum value" do
        temporary do
          reinit_example_models

          User.create({first_name: "John", posts_count: 30})
          User.create({first_name: "Jane", posts_count: 10})
          User.create({first_name: "Bob", posts_count: 20})

          max = User.query.max("posts_count", Int32)
          max.should eq 30
        end
      end
    end

    describe "#avg" do
      it "returns average value" do
        temporary do
          reinit_example_models

          User.create({first_name: "John", posts_count: 10})
          User.create({first_name: "Jane", posts_count: 20})
          User.create({first_name: "Bob", posts_count: 30})

          # AVG returns numeric type in PostgreSQL
          avg = User.query.avg("posts_count", PG::Numeric)
          avg.to_f.should eq 20.0
        end
      end
    end

    describe "#agg" do
      it "allows custom aggregation functions" do
        temporary do
          reinit_example_models

          User.create({first_name: "John", posts_count: 1})
          User.create({first_name: "Jane", posts_count: 2})
          User.create({first_name: "Bob", posts_count: 3})
          User.create({first_name: "Alice", posts_count: 4})
          User.create({first_name: "Charlie", posts_count: 5})

          # Test custom aggregation
          total = User.query.agg("SUM(posts_count)", Int64)
          total.should eq 15
        end
      end
    end
  end
end
