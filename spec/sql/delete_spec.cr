require "../spec_helper"

module DeleteSpec
  extend self

  def delete_request
    Lustra::SQL::DeleteQuery.new
  end

  def one_request
    select_request
      .select("MAX(updated_at)")
      .from(:users)
  end

  def complex_query
    Lustra::SQL.select.from(:users)
      .join(:role_users) { role_users.user_id == users.id }
      .join(:roles) { role_users.role_id == roles.id }
      .where({role: ["admin", "superadmin"]})
      .order_by({priority: :desc, name: :asc})
      .limit(1)
  end

  describe "Lustra::SQL" do
    describe "DeleteQuery" do
      it "create a simple delete" do
        r = delete_request.from("table")
        r.to_sql.should eq "DELETE FROM table"
      end

      it "create a delete with where parameter" do
        r = delete_request.from(:table).where({id: complex_query})
        r.to_sql.should eq "DELETE FROM \"table\" WHERE \"id\" IN (SELECT * " +
                           "FROM \"users\" " +
                           "INNER JOIN \"role_users\" ON (\"role_users\".\"user_id\" = \"users\".\"id\") " +
                           "INNER JOIN \"roles\" ON (\"role_users\".\"role_id\" = \"roles\".\"id\") " +
                           "WHERE \"role\" IN ('admin', 'superadmin') " +
                           "ORDER BY \"priority\" DESC, \"name\" ASC " +
                           "LIMIT 1)"
      end
    end
  end
end
