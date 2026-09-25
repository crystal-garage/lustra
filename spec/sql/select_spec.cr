require "spec"

require "../spec_helper"

module SelectSpec
  extend self

  def complex_query
    Lustra::SQL.select.from(:users)
      .join(:role_users) { var("role_users", "user_id") == users.id }
      .join(:roles) { var("role_users", "role_id") == var("roles", "id") }
      .where({role: ["admin", "superadmin"]})
      .order_by({priority: :desc, name: :asc})
      .limit(50)
      .offset(50)
  end

  describe "Lustra::SQL" do
    describe "SelectQuery" do
      it "create a simple request" do
        r = Lustra::SQL.select
        r.to_sql.should eq "SELECT *"
      end

      it "duplicate itself" do
        cq_2 = complex_query.dup
        cq_2.to_sql.should eq complex_query.to_sql
      end

      it "preserves the original query's hooks after executing a duplicate" do
        calls = 0
        original = Lustra::SQL.select("1").before_query { calls += 1 }
        copy = original.dup

        copy.to_a
        calls.should eq(1)
        original.to_a
        calls.should eq(2)
      end

      it "does not add a duplicate's hooks to the original query" do
        calls = 0
        original = Lustra::SQL.select("1")
        copy = original.dup.before_query { calls += 1 }

        original.to_a
        calls.should eq(0)
        copy.to_a
        calls.should eq(1)
      end

      describe "query hooks" do
        it "runs hooks in order once, before building the executed SQL" do
          calls = [] of Int32
          query = Lustra::SQL.select("1 AS value")
          query.before_query { calls << 1 }.should be(query)
          query.before_query do
            calls << 2
            query.clear_select.select("2 AS value")
          end

          query.to_sql.should eq("SELECT 1 AS value")
          calls.should be_empty
          2.times { query.to_a.first["value"].should eq(2) }
          calls.should eq([1, 2])

          query.before_query { calls << 3 }
          query.scalar(Int32).should eq(2)
          query.scalar(Int32).should eq(2)
          calls.should eq([1, 2, 3])
        end

        it "clears all hooks on a duplicate and allows new hooks" do
          calls = [] of String
          original = Lustra::SQL.select("1").before_query { calls << "original" }
          copy = original.dup.before_query { calls << "copy" }

          copy.clear_before_query_triggers.should be(copy)
          copy.to_a
          calls.should be_empty
          copy.before_query { calls << "replacement" }
          copy.to_a
          original.to_a
          calls.should eq(["replacement", "original"])
        end

        it "passes the executing duplicate to contextual hooks" do
          original = Lustra::SQL.select("1 AS value")
          original.before_query_with_context do |executing|
            executing.clear_select.select("2 AS value")
          end
          copy = original.dup

          copy.to_a.first["value"].should eq(2)
          original.to_sql.should eq("SELECT 1 AS value")
          original.to_a.first["value"].should eq(2)
        end

        it "retains all hooks for retry when a callback raises" do
          calls = [] of Int32
          fail_hook = true
          query = Lustra::SQL.select("1 / 0")
            .before_query { calls << 1 }
            .before_query do
              calls << 2
              raise "hook failed" if fail_hook
            end
            .before_query { calls << 3 }

          expect_raises(Exception, "hook failed") { query.to_a }
          calls.should eq([1, 2])

          fail_hook = false
          query.clear_select.select("1")
          2.times { query.to_a }
          calls.should eq([1, 2, 1, 2, 3])
        end

        it "does not rerun completed hooks after a database error" do
          calls = 0
          query = Lustra::SQL.select("1 / 0").before_query { calls += 1 }

          expect_raises(Lustra::SQL::Error, /division by zero/) { query.to_a }
          calls.should eq(1)
          query.clear_select.select("1").to_a
          calls.should eq(1)
        end

        it "does not trigger or consume hooks through execute" do
          calls = 0
          query = Lustra::SQL.select("1").before_query { calls += 1 }

          query.execute
          calls.should eq(0)
          query.to_a
          calls.should eq(1)
        end
      end

      it "transfert to delete method" do
        r = Lustra::SQL.select("*").from(:users).where { raw("users.id") > 1000 }
        r.to_delete.to_sql.should eq "DELETE FROM \"users\" WHERE (users.id > 1000)"
      end

      it "adds a returning clause to a delete" do
        r = Lustra::SQL.select("*").from(:users).where { var("users", "id") > 1000 }

        r.to_delete
          .returning("id, email")
          .to_sql.should eq "DELETE FROM \"users\" WHERE (\"users\".\"id\" > 1000) RETURNING id, email"
      end

      it "transfert to update method" do
        r = Lustra::SQL.select("*").from(:users).where { var("users", "id") > 1000 }
        r.to_update.set(x: 1).to_sql.should eq "UPDATE \"users\" SET \"x\" = 1 WHERE (\"users\".\"id\" > 1000)"
      end

      it "adds a returning clause to an update" do
        r = Lustra::SQL.select("*").from(:users).where { var("users", "id") > 1000 }

        r.to_update
          .set(x: 1)
          .returning("id, email")
          .to_sql.should eq "UPDATE \"users\" SET \"x\" = 1 WHERE (\"users\".\"id\" > 1000) RETURNING id, email"
      end

      describe "cte" do
        it "build request with CTE" do
          # Simple CTE
          cte = Lustra::SQL.select.from(:users_info).where("x > 10")
          sql = Lustra::SQL.select.from(:ui).with_cte("ui", cte).to_sql
          sql.should eq "WITH ui AS (SELECT * FROM \"users_info\" WHERE x > 10) SELECT * FROM \"ui\""

          # Complex CTE
          cte1 = Lustra::SQL.select.from(:users_info).where { a == b }
          cte2 = Lustra::SQL.select.from(:just_another_table).where { users_infos.x == just_another_table.w }
          sql = Lustra::SQL.select.with_cte({ui: cte1, at: cte2}).from(:at).to_sql
          sql.should eq "WITH ui AS (SELECT * FROM \"users_info\" WHERE (\"a\" = \"b\"))," +
                        " at AS (SELECT * FROM \"just_another_table\" WHERE (" +
                        "\"users_infos\".\"x\" = \"just_another_table\".\"w\")) SELECT * FROM \"at\""
        end
      end
    end
  end
end
