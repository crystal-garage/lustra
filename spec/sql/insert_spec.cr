require "spec"

require "../spec_helper"

module InsertSpec
  extend self

  def insert_request
    Lustra::SQL::InsertQuery.new(:users)
  end

  def with_insert_connection_tables(&)
    Lustra::SQL.transaction do
      Lustra::SQL.transaction("secondary") do
        Lustra::SQL.execute("CREATE TEMP TABLE insert_connection_selection (value integer) ON COMMIT DROP")
        Lustra::SQL.execute("secondary", "CREATE TEMP TABLE insert_connection_selection (value integer) ON COMMIT DROP")
        yield
      end
    end
  end

  describe "Lustra::SQL" do
    describe "InsertQuery" do
      {
        {"Float32 infinity", Float32::INFINITY, "Infinity"},
        {"Float32 negative infinity", -Float32::INFINITY, "-Infinity"},
        {"Float32 NaN", Float32::NAN, "NaN"},
        {"Float64 infinity", Float64::INFINITY, "Infinity"},
        {"Float64 negative infinity", -Float64::INFINITY, "-Infinity"},
        {"Float64 NaN", Float64::NAN, "NaN"},
      }.each do |description, value, expected|
        it "inserts #{description} into real and double precision columns" do
          temporary do
            Lustra::SQL.execute("CREATE TEMP TABLE nonfinite_insert (single_value real, double_value double precision)")

            row = Lustra::SQL.insert(:nonfinite_insert, {single_value: value, double_value: value})
              .returning("single_value::text AS single_value, double_value::text AS double_value").execute

            row["single_value"].should eq(expected)
            row["double_value"].should eq(expected)
          end
        end
      end

      it "clears accumulated rows so an insert can use new columns" do
        temporary do
          Lustra::SQL.execute("CREATE TEMP TABLE reset_insert_values (value integer DEFAULT 7, label text DEFAULT 'default')")
          query = Lustra::SQL.insert_into(:reset_insert_values)
            .values({value: 1}).values({value: 2}).returning("value, label")
          query.execute["value"].should eq(2)

          replacement = query.clear_values.values({label: "replacement"}).execute
          replacement["value"].should eq(7)
          replacement["label"].should eq("replacement")

          Lustra::SQL.select.from(:reset_insert_values).order_by(:value).order_by(:label)
            .to_a.map { |row| {row["value"], row["label"]} }
            .should eq([{1, "default"}, {2, "default"}, {7, "replacement"}])
        end
      end

      it "inserts database defaults after clear_values and retains columns for reuse" do
        temporary do
          Lustra::SQL.execute("CREATE TEMP TABLE reset_insert_defaults (other integer DEFAULT 99, value integer DEFAULT 7)")
          query = Lustra::SQL.insert_into(:reset_insert_defaults, {value: 1}).returning("value")

          query.clear_values.execute["value"].should eq(7)
          query.values(Lustra::SQL.select("11")).execute["value"].should eq(11)
          Lustra::SQL.select.from(:reset_insert_defaults).order_by(:value)
            .to_a.map { |row| {row["other"], row["value"]} }.should eq([{99, 7}, {99, 11}])
        end
      end

      it "can switch between literal rows and an INSERT SELECT after clearing values" do
        temporary do
          Lustra::SQL.execute("CREATE TEMP TABLE reset_insert_source (value integer)")
          query = Lustra::SQL.insert_into(:reset_insert_source, {value: 99}).returning("value")

          query.clear_values.values(Lustra::SQL.select("5 AS value")).execute["value"].should eq(5)
          query.clear_values.values({value: 9}).execute["value"].should eq(9)

          Lustra::SQL.select.from(:reset_insert_source).order_by(:value).pluck_col(:value).should eq([5, 9])
        end
      end

      {:nothing, :update}.each do |action|
        it "restores unique-constraint errors after clearing ON CONFLICT DO #{action}" do
          temporary do
            Lustra::SQL.execute("CREATE TEMP TABLE reset_insert_conflict (id integer PRIMARY KEY, value integer)")
            Lustra::SQL.insert_into(:reset_insert_conflict, {id: 1, value: 1}).execute
            query = Lustra::SQL.insert_into(:reset_insert_conflict, {id: 1, value: 2})
              .on_conflict("(id)").returning("value")
            if action == :update
              query.do_update(&.set(value: 2))
            else
              query.do_nothing
            end
            query.execute
            Lustra::SQL.select("value").from(:reset_insert_conflict).scalar(Int32)
              .should eq(action == :update ? 2 : 1)

            query.clear_conflict
            Lustra::SQL.with_savepoint do
              expect_raises(PQ::PQError, /duplicate key/) { query.execute }
              Lustra::SQL.rollback
            end

            query.on_conflict("(id)").do_update(&.set(value: 3))
            query.execute["value"].should eq(3)
            Lustra::SQL.select.from(:reset_insert_conflict).count.should eq(1)
          end
        end
      end

      it "executes inserts on the query's selected connection" do
        with_insert_connection_tables do
          Lustra::SQL.insert_into(:insert_connection_selection, {value: 1})
            .use_connection("secondary")
            .execute

          Lustra::SQL.select.from(:insert_connection_selection).count.should eq(0)
          Lustra::SQL.select.from(:insert_connection_selection).use_connection("secondary").count.should eq(1)
        end
      end

      it "executes inserts with RETURNING on the query's selected connection" do
        with_insert_connection_tables do
          result = Lustra::SQL.insert_into(:insert_connection_selection, {value: 2})
            .use_connection("secondary")
            .returning("value")
            .execute

          result["value"].should eq(2)
          Lustra::SQL.select.from(:insert_connection_selection).count.should eq(0)
          Lustra::SQL.select.from(:insert_connection_selection).use_connection("secondary").count.should eq(1)
        end
      end

      it "counts inserted rows on the query's selected connection" do
        with_insert_connection_tables do
          affected = Lustra::SQL.insert_into(:insert_connection_selection, {value: 3})
            .use_connection("secondary")
            .execute_and_count

          affected.should eq(1)
          Lustra::SQL.select.from(:insert_connection_selection).count.should eq(0)
          Lustra::SQL.select.from(:insert_connection_selection).use_connection("secondary").count.should eq(1)
        end
      end

      it "honors explicit insert connection overrides" do
        with_insert_connection_tables do
          Lustra::SQL.insert_into(:insert_connection_selection, {value: 1})
            .use_connection("secondary")
            .execute("default")

          result = Lustra::SQL.insert_into(:insert_connection_selection, {value: 2})
            .use_connection("secondary")
            .returning("value")
            .execute("default")
          result["value"].should eq(2)

          affected = Lustra::SQL.insert_into(:insert_connection_selection, {value: 3})
            .use_connection("secondary")
            .execute_and_count("default")
          affected.should eq(1)

          Lustra::SQL.select.from(:insert_connection_selection).count.should eq(3)
          Lustra::SQL.select.from(:insert_connection_selection).use_connection("secondary").count.should eq(0)
        end
      end

      it "builds an insert with the zero-argument fluent API" do
        Lustra::SQL.insert
          .into(:users)
          .values({a: "c", b: 12})
          .to_sql
          .should eq %(INSERT INTO "users" ("a", "b") VALUES ('c', 12))
      end

      it "build an insert" do
        insert_request.values({a: "c", b: 12}).to_sql.should eq(
          "INSERT INTO \"users\" (\"a\", \"b\") VALUES ('c', 12)"
        )
      end

      it "aligns named tuple values with the first row's columns" do
        insert_request
          .values({first_name: "Ada", last_name: "Lovelace"})
          .values({last_name: "Hopper", first_name: "Grace"})
          .to_sql
          .should eq %(INSERT INTO "users" ("first_name", "last_name") VALUES ('Ada', 'Lovelace'),\n('Grace', 'Hopper'))
      end

      it "persists bulk hash rows by column name regardless of key order" do
        temporary do
          Lustra::SQL.execute("CREATE TEMP TABLE bulk_insert_alignment (first_name text, last_name text)")

          rows = [
            {"first_name" => "Ada", "last_name" => "Lovelace"} of Lustra::SQL::Symbolic => Lustra::SQL::InsertQuery::Inserable,
            {"last_name" => "Hopper", "first_name" => "Grace"} of Lustra::SQL::Symbolic => Lustra::SQL::InsertQuery::Inserable,
          ]

          Lustra::SQL.insert_into(:bulk_insert_alignment).values(rows).execute

          persisted = Lustra::SQL.select.from(:bulk_insert_alignment).order_by(:first_name).to_a
          persisted.map { |row| {row["first_name"], row["last_name"]} }.should eq([
            {"Ada", "Lovelace"},
            {"Grace", "Hopper"},
          ])
        end
      end

      it "rejects a bulk row with a missing column" do
        query = insert_request.values({first_name: "Ada", last_name: "Lovelace"})

        expect_raises(Lustra::SQL::QueryBuildingError) do
          query.values({first_name: "Grace"}).to_sql
        end
      end

      it "rejects a bulk row with an extra column" do
        query = insert_request.values({first_name: "Ada", last_name: "Lovelace"})

        expect_raises(Lustra::SQL::QueryBuildingError) do
          query.values({first_name: "Grace", last_name: "Hopper", nickname: "Amazing Grace"}).to_sql
        end
      end

      it "rejects a bulk row with different columns of the same count" do
        query = insert_request.values({first_name: "Ada", last_name: "Lovelace"})

        expect_raises(Lustra::SQL::QueryBuildingError) do
          query.values({first_name: "Grace", nickname: "Amazing Grace"}).to_sql
        end
      end

      it "build an insert from sql" do
        insert_request.values(
          Lustra::SQL.select.from(:old_users)
            .where { old_users.id > 100 }
        ).to_sql.should eq(
          "INSERT INTO \"users\" (SELECT * FROM \"old_users\" WHERE (\"old_users\".\"id\" > 100))"
        )
      end

      it "insert with ON CONFLICT" do
        insert_request.values({a: "c", b: 12}).on_conflict("(a)").do_nothing
          .to_sql.should eq(
          "INSERT INTO \"users\" (\"a\", \"b\") VALUES ('c', 12) ON CONFLICT (a) DO NOTHING"
        )

        req = insert_request.values({a: "c", b: 12}).on_conflict("(b)").do_update do |upd|
          upd.set(a: 1).where { b == 2 }
        end

        req.to_sql.should eq(
          %(INSERT INTO "users" ("a", "b") VALUES ('c', 12) ON CONFLICT (b) DO UPDATE SET "a" = 1 WHERE ("b" = 2))
        )

        req = insert_request.values({a: "c", b: 12}).on_conflict { age < 18 }.do_update do |upd|
          upd.set(a: 1).where { b == 2 }
        end

        req.to_sql.should eq(
          %(INSERT INTO "users" ("a", "b") VALUES ('c', 12) ON CONFLICT WHERE ("age" < 18) DO UPDATE SET "a" = 1 WHERE ("b" = 2))
        )
      end

      it "build an empty insert?" do
        insert_request.to_sql.should eq(
          "INSERT INTO \"users\" DEFAULT VALUES"
        )
      end

      it "insert unsafe values" do
        insert_request.values({created_at: Lustra::Expression.unsafe("NOW()")})
          .to_sql
          .should eq "INSERT INTO \"users\" (\"created_at\") VALUES (NOW())"
      end
    end
  end
end
