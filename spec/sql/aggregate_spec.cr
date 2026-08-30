require "../spec_helper"
require "../data/example_models"

module AggregateSpec
  extend self

  describe "Lustra::SQL::Query::Aggregate" do
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
