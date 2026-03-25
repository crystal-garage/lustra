require "../../spec_helper"

module OrderBySpec
  describe Lustra::SQL::Query::OrderBy do
    it "stacks order by clauses" do
      qry = Lustra::SQL.select.from("users").order_by(id: :desc).order_by(name: :asc)
      qry.to_sql.should eq(%(SELECT * FROM users ORDER BY "id" DESC, "name" ASC))
    end

    it "clears order by clauses" do
      qry = Lustra::SQL.select.from("users").order_by(id: :desc, name: :asc)
      qry.clear_order_bys.order_by(id: :asc)
        .to_sql.should eq(%(SELECT * FROM users ORDER BY "id" ASC))
    end

    it "can be reverted" do
      qry = Lustra::SQL.select.from("users").order_by(id: :desc).order_by(:name, :asc, :nulls_first)

      qry.to_sql.should eq(%(SELECT * FROM users ORDER BY "id" DESC, "name" ASC NULLS FIRST))
      qry.reverse_order_by

      qry.to_sql.should eq(%(SELECT * FROM users ORDER BY "id" ASC, "name" DESC NULLS LAST))
    end

    it "allows definition of NULLS FIRST and NULLS LAST" do
      Lustra::SQL.select.from("users").order_by("email", :asc, :nulls_last)
        .to_sql.should eq("SELECT * FROM users ORDER BY email ASC NULLS LAST")

      Lustra::SQL.select.from("users").order_by(email: {:desc, :nulls_first})
        .to_sql.should eq(%(SELECT * FROM users ORDER BY "email" DESC NULLS FIRST))
    end

    describe "#in_order_of" do
      it "orders by a custom sequence of string values" do
        qry = Lustra::SQL.select.from("posts").in_order_of(:status, ["started", "enrolled", "completed"])
        qry.to_sql.should eq(
          %(SELECT * FROM posts ORDER BY CASE "status" WHEN 'started' THEN 0 WHEN 'enrolled' THEN 1 WHEN 'completed' THEN 2 ELSE 3 END ASC)
        )
      end

      it "orders by a custom sequence of integer values" do
        qry = Lustra::SQL.select.from("posts").in_order_of(:priority, [3, 1, 2])
        qry.to_sql.should eq(
          %(SELECT * FROM posts ORDER BY CASE "priority" WHEN 3 THEN 0 WHEN 1 THEN 1 WHEN 2 THEN 2 ELSE 3 END ASC)
        )
      end

      it "accepts a raw string column expression" do
        qry = Lustra::SQL.select.from("posts").in_order_of("\"posts\".\"status\"", ["draft", "published"])
        qry.to_sql.should eq(
          %(SELECT * FROM posts ORDER BY CASE "posts"."status" WHEN 'draft' THEN 0 WHEN 'published' THEN 1 ELSE 2 END ASC)
        )
      end

      it "can be combined with other order_by clauses" do
        qry = Lustra::SQL.select.from("posts")
          .in_order_of(:status, ["started", "completed"])
          .order_by(:id, :desc)
        qry.to_sql.should eq(
          %(SELECT * FROM posts ORDER BY CASE "status" WHEN 'started' THEN 0 WHEN 'completed' THEN 1 ELSE 2 END ASC, "id" DESC)
        )
      end

      it "places unlisted values last via the ELSE clause" do
        qry = Lustra::SQL.select.from("posts").in_order_of(:status, ["a", "b"])
        # values not in ["a", "b"] get ELSE 2 (= values.size), sorting them last
        qry.to_sql.should contain("ELSE 2 END")
      end
    end
  end
end
