require "../../spec_helper"

module OrderBySpec
  describe Lustra::SQL::Query::OrderBy do
    it "stacks" do
      qry = Lustra::SQL.select.from("users").order_by(id: :desc).order_by(name: :asc)
      qry.to_sql.should eq(%(SELECT * FROM users ORDER BY "id" DESC, "name" ASC))
    end

    it "lustras" do
      qry = Lustra::SQL.select.from("users").order_by(id: :desc, name: :asc)
      qry.clear_order_bys.order_by(id: :asc)
        .to_sql.should eq(%(SELECT * FROM users ORDER BY "id" ASC))
    end

    it "be reverted" do
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
  end
end
