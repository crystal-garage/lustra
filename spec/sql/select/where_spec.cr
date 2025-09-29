require "../../spec_helper"

module WhereSpec
  def self.complex_query
    Lustra::SQL.select.from(:users)
      .join(:role_users) { var("role_users", "user_id") == users.id }
      .join(:roles) { var("role_users", "role_id") == var("roles", "id") }
      .where({role: ["admin", "superadmin"]})
      .order_by({priority: :desc, name: :asc})
      .limit(50)
      .offset(50)
  end

  describe Lustra::SQL::Query::Where do
    it "accepts simple string as parameter" do
      r = Lustra::SQL.select.from(:users).where("a = b")
      r.to_sql.should eq %(SELECT * FROM "users" WHERE a = b)
    end

    it "accepts NamedTuple argument" do
      # tuple as argument
      q = Lustra::SQL.select.from(:users).where({user_id: 1})
      q.to_sql.should eq %(SELECT * FROM "users" WHERE ("user_id" = 1))

      # splatted tuple
      q = Lustra::SQL.select.from(:users).where(user_id: 2)
      q.to_sql.should eq %(SELECT * FROM "users" WHERE ("user_id" = 2))
    end

    it "transforms Nil to NULL" do
      q = Lustra::SQL.select.from(:users).where({user_id: nil})
      q.to_sql.should eq %(SELECT * FROM "users" WHERE ("user_id" IS NULL))
    end

    it "uses IN operator if an array is found" do
      q = Lustra::SQL.select.from(:users).where({user_id: [1, 2, 3, 4, "hello"]})
      q.to_sql.should eq %(SELECT * FROM "users" WHERE "user_id" IN (1, 2, 3, 4, 'hello'))
    end

    it "accepts ranges as tuple value and transform them" do
      Lustra::SQL.select.from(:users).where({x: 1..4}).to_sql
        .should eq %(SELECT * FROM "users" WHERE ("x" >= 1 AND "x" <= 4))
      Lustra::SQL.select.from(:users).where({x: 1...4}).to_sql
        .should eq %(SELECT * FROM "users" WHERE ("x" >= 1 AND "x" < 4))
    end

    it "allows prepared query" do
      r = Lustra::SQL.select.from(:users).where("a LIKE ?", "hello")
      r.to_sql.should eq "SELECT * FROM \"users\" WHERE a LIKE 'hello'"

      r = Lustra::SQL.select.from(:users).where("a LIKE ?", "hello")
      r.to_sql.should eq "SELECT * FROM \"users\" WHERE a LIKE 'hello'"
    end

    it "manages ranges" do
      Lustra::SQL.select.from(:users).where({x: 1..4}).to_sql
        .should eq "SELECT * FROM \"users\" WHERE (\"x\" >= 1 AND \"x\" <= 4)"

      Lustra::SQL.select.from(:users).where({x: 1...4}).to_sql
        .should eq "SELECT * FROM \"users\" WHERE (\"x\" >= 1 AND \"x\" < 4)"
    end

    it "prepare query" do
      r = Lustra::SQL.select.from(:users).where("a LIKE ?", "hello")
      r.to_sql.should eq "SELECT * FROM \"users\" WHERE a LIKE 'hello'"
    end

    it "raises exception with prepared query" do
      expect_raises Lustra::SQL::QueryBuildingError do
        Lustra::SQL.select.from(:users).where("a LIKE ? AND b = ?", "hello")
      end
    end

    it "prepare query with tuple" do
      r = Lustra::SQL.select.from(:users).where("a LIKE :hello AND b LIKE :world",
        hello: "h", world: "w")
      r.to_sql.should eq "SELECT * FROM \"users\" WHERE a LIKE 'h' AND b LIKE 'w'"

      # check escaping `::`
      r = Lustra::SQL.select.from(:users).where("a::text LIKE :hello", hello: "h")
      r.to_sql.should eq "SELECT * FROM \"users\" WHERE a::text LIKE 'h'"

      # check escaping the first character because of the regexp solution I used
      r = Lustra::SQL.select.from(:users).where(":text", text: "ok")
      r.to_sql.should eq "SELECT * FROM \"users\" WHERE 'ok'"
    end

    it "raises exception if a tuple element is not found" do
      expect_raises Lustra::SQL::QueryBuildingError do
        Lustra::SQL.select.from(:users).where("a LIKE :halo AND b LIKE :world", hello: "h", world: "w")
      end

      expect_raises Lustra::SQL::QueryBuildingError do
        Lustra::SQL.select.from(:users).or_where("a LIKE :halo AND b LIKE :world", hello: "h", world: "w")
      end
    end

    it "prepare group by query" do
      Lustra::SQL.select.select("role").from(:users).group_by(:role).order_by(:role).to_sql.should eq \
        "SELECT role FROM \"users\" GROUP BY \"role\" ORDER BY \"role\" ASC"
    end

    it "use different comparison and arithmetic operators" do
      r = Lustra::SQL.select.from(:users).where { users.id > 1 }
      r.to_sql.should eq "SELECT * FROM \"users\" WHERE (\"users\".\"id\" > 1)"
      r = Lustra::SQL.select.from(:users).where { users.id < 1 }
      r.to_sql.should eq "SELECT * FROM \"users\" WHERE (\"users\".\"id\" < 1)"
      r = Lustra::SQL.select.from(:users).where { users.id >= 1 }
      r.to_sql.should eq "SELECT * FROM \"users\" WHERE (\"users\".\"id\" >= 1)"
      r = Lustra::SQL.select.from(:users).where { users.id <= 1 }
      r.to_sql.should eq "SELECT * FROM \"users\" WHERE (\"users\".\"id\" <= 1)"
      r = Lustra::SQL.select.from(:users).where { users.id * 2 == 1 }
      r.to_sql.should eq "SELECT * FROM \"users\" WHERE ((\"users\".\"id\" * 2) = 1)"
      r = Lustra::SQL.select.from(:users).where { users.id / 2 == 1 }
      r.to_sql.should eq "SELECT * FROM \"users\" WHERE ((\"users\".\"id\" / 2) = 1)"
      r = Lustra::SQL.select.from(:users).where { users.id + 2 == 1 }
      r.to_sql.should eq "SELECT * FROM \"users\" WHERE ((\"users\".\"id\" + 2) = 1)"
      r = Lustra::SQL.select.from(:users).where { users.id - 2 == 1 }
      r.to_sql.should eq "SELECT * FROM \"users\" WHERE ((\"users\".\"id\" - 2) = 1)"
      r = Lustra::SQL.select.from(:users).where { -users.id < -1000 }
      r.to_sql.should eq "SELECT * FROM \"users\" WHERE (-\"users\".\"id\" < -1000)"
    end

    it "use expression engine equal" do
      r = Lustra::SQL.select.from(:users).where { users.id == var("test") }
      r.to_sql.should eq "SELECT * FROM \"users\" WHERE (\"users\".\"id\" = \"test\")"
    end

    it "use expression engine not equals" do
      r = Lustra::SQL.select.from(:users).where { users.id != 1 }
      r.to_sql.should eq "SELECT * FROM \"users\" WHERE (\"users\".\"id\" <> 1)"
    end

    it "use expression engine not null" do
      r = Lustra::SQL.select.from(:users).where { users.id != nil }
      r.to_sql.should eq "SELECT * FROM \"users\" WHERE (\"users\".\"id\" IS NOT NULL)"
    end

    it "use expression engine null" do
      r = Lustra::SQL.select.from(:users).where { users.id == nil }
      r.to_sql.should eq "SELECT * FROM \"users\" WHERE (\"users\".\"id\" IS NULL)"
    end

    describe "where expressions" do
      it "where.where" do
        now = Time.local
        r = Lustra::SQL.select.from(:users).where { users.id == nil }.where do
          var("users", "updated_at") >= now
        end
        r.to_sql.should eq "SELECT * FROM \"users\" WHERE (\"users\".\"id\" IS NULL) " +
                           "AND (\"users\".\"updated_at\" >= #{Lustra::Expression[now]})"
      end

      it "where.or_where" do
        now = Time.local
        r = Lustra::SQL.select.from(:users).where { users.id == nil }.or_where do
          var("users", "updated_at") >= now
        end
        r.to_sql.should eq "SELECT * FROM \"users\" WHERE ((\"users\".\"id\" IS NULL) " +
                           "OR (\"users\".\"updated_at\" >= #{Lustra::Expression[now]}))"
      end

      it "op(:&)/op(:|)" do
        r = Lustra::SQL.select.from(:users).where do
          ((raw("users.id") > 100) & (raw("users.visible") == true)) |
            (raw("users.role") == "superadmin")
        end

        r.to_sql.should eq "SELECT * FROM \"users\" WHERE (((users.id > 100) " +
                           "AND (users.visible = TRUE)) OR (users.role = 'superadmin'))"
      end

      it "between(a, b)" do
        Lustra::SQL.select.where { x.between(1, 2) }
          .to_sql.should eq(%(SELECT * WHERE ("x" BETWEEN 1 AND 2)))

        Lustra::SQL.select.where { not(x.between(1, 2)) }
          .to_sql.should eq(%(SELECT * WHERE NOT ("x" BETWEEN 1 AND 2)))
      end

      it "custom functions" do
        Lustra::SQL.select.where { ops_transform(x, "string", raw("INTERVAL '2 seconds'")) }
          .to_sql.should eq(%(SELECT * WHERE ops_transform("x", 'string', INTERVAL '2 seconds')))
      end

      it "in?(array)" do
        Lustra::SQL.select.where { x.in?([1, 2, 3, 4]) }
          .to_sql.should eq(%(SELECT * WHERE "x" IN (1, 2, 3, 4)))

        Lustra::SQL.select.where { x.in?({1, 2, 3, 4}) }
          .to_sql.should eq(%(SELECT * WHERE "x" IN (1, 2, 3, 4)))
      end

      it "in?(range)" do
        # Simple number
        Lustra::SQL.select.from(:users).where { users.id.in?(1..3) }.to_sql
          .should eq "SELECT * FROM \"users\" WHERE (\"users\".\"id\" >= 1 AND \"users\".\"id\" <= 3)"

        # Date range.
        range = 2.day.ago..1.day.ago

        Lustra::SQL.select.from(:users).where { created_at.in?(range) }.to_sql
          .should eq "SELECT * FROM \"users\" WHERE " +
                     "(\"created_at\" >= #{Lustra::Expression[range.begin]} AND" +
                     " \"created_at\" <= #{Lustra::Expression[range.end]})"

        # Exclusive range
        Lustra::SQL.select.from(:users).where { users.id.in?(1...3) }.to_sql
          .should eq "SELECT * FROM \"users\" WHERE (\"users\".\"id\" >= 1" +
                     " AND \"users\".\"id\" < 3)"
      end

      it "in?(sub_query)" do
        sub_query = Lustra::SQL.select("id").from("users")
        Lustra::SQL.select.where { x.in?(sub_query) }
          .to_sql.should eq(%(SELECT * WHERE "x" IN (SELECT id FROM users)))
      end

      it "unary minus" do
        Lustra::SQL.select.where { -x > 2 }
          .to_sql.should eq(%(SELECT * WHERE (-"x" > 2)))
      end

      it "not()" do
        Lustra::SQL.select.where { not(raw("TRUE")) }
          .to_sql.should eq(%(SELECT * WHERE NOT TRUE))

        Lustra::SQL.select.where { ~(raw("TRUE")) }
          .to_sql.should eq(%(SELECT * WHERE NOT TRUE))
      end

      it "nil" do
        Lustra::SQL.select.where { x == nil }
          .to_sql.should eq(%(SELECT * WHERE ("x" IS NULL)))
        Lustra::SQL.select.where { x != nil }
          .to_sql.should eq(%(SELECT * WHERE ("x" IS NOT NULL)))
      end

      it "raw()" do
        Lustra::SQL.select.where { raw("Anything") }
          .to_sql.should eq(%(SELECT * WHERE Anything))

        Lustra::SQL.select.where { raw("x > ?", 1) }
          .to_sql.should eq(%(SELECT * WHERE x > 1))

        Lustra::SQL.select.where { raw("x > :num", num: 2) }
          .to_sql.should eq(%(SELECT * WHERE x > 2))
      end

      it "var()" do
        Lustra::SQL.select.where { var("public", "users", "id") < 1000 }
          .to_sql.should eq(%(SELECT * WHERE ("public"."users"."id" < 1000)))
      end
    end

    describe "where_not" do
      it "accepts simple string as parameter" do
        r = Lustra::SQL.select.from(:users).where_not("a = b")
        r.to_sql.should eq %(SELECT * FROM "users" WHERE NOT a = b)
      end

      it "accepts NamedTuple argument" do
        q = Lustra::SQL.select.from(:users).where_not({user_id: 1})
        q.to_sql.should eq %(SELECT * FROM "users" WHERE NOT ("user_id" = 1))

        q = Lustra::SQL.select.from(:users).where_not(user_id: 2)
        q.to_sql.should eq %(SELECT * FROM "users" WHERE NOT ("user_id" = 2))
      end

      it "transforms Nil to NULL" do
        q = Lustra::SQL.select.from(:users).where_not({user_id: nil})
        q.to_sql.should eq %(SELECT * FROM "users" WHERE NOT ("user_id" IS NULL))
      end

      it "uses NOT IN operator if an array is found" do
        q = Lustra::SQL.select.from(:users).where_not({user_id: [1, 2, 3, 4, "hello"]})
        q.to_sql.should eq %(SELECT * FROM "users" WHERE NOT "user_id" IN (1, 2, 3, 4, 'hello'))
      end

      it "accepts ranges as tuple value and transform them" do
        Lustra::SQL.select.from(:users).where_not({x: 1..4}).to_sql
          .should eq %(SELECT * FROM "users" WHERE NOT ("x" >= 1 AND "x" <= 4))
        Lustra::SQL.select.from(:users).where_not({x: 1...4}).to_sql
          .should eq %(SELECT * FROM "users" WHERE NOT ("x" >= 1 AND "x" < 4))
      end

      it "allows prepared query" do
        r = Lustra::SQL.select.from(:users).where_not("a LIKE ?", "hello")
        r.to_sql.should eq "SELECT * FROM \"users\" WHERE NOT a LIKE 'hello'"

        r = Lustra::SQL.select.from(:users).where_not("a LIKE :hello", hello: "world")
        r.to_sql.should eq "SELECT * FROM \"users\" WHERE NOT a LIKE 'world'"
      end

      it "works with expression engine" do
        r = Lustra::SQL.select.from(:users).where_not { users.id == 1 }
        r.to_sql.should eq "SELECT * FROM \"users\" WHERE NOT (\"users\".\"id\" = 1)"

        r = Lustra::SQL.select.from(:users).where_not { users.active == true }
        r.to_sql.should eq "SELECT * FROM \"users\" WHERE NOT (\"users\".\"active\" = TRUE)"
      end
    end

    describe "like and ilike operators" do
      it "supports like operator in DSL" do
        r = Lustra::SQL.select.from(:users).where { users.email.like("%@gmail.com") }
        r.to_sql.should eq %(SELECT * FROM "users" WHERE ("users"."email" LIKE '%@gmail.com'))
      end

      it "supports ilike operator in DSL" do
        r = Lustra::SQL.select.from(:users).where { users.email.ilike("%@gmail.com") }
        r.to_sql.should eq %(SELECT * FROM "users" WHERE ("users"."email" ILIKE '%@gmail.com'))
      end

      it "supports like with case sensitive pattern" do
        r = Lustra::SQL.select.from(:users).where { users.name.like("John%") }
        r.to_sql.should eq %(SELECT * FROM "users" WHERE ("users"."name" LIKE 'John%'))
      end

      it "supports ilike with case insensitive pattern" do
        r = Lustra::SQL.select.from(:users).where { users.name.ilike("john%") }
        r.to_sql.should eq %(SELECT * FROM "users" WHERE ("users"."name" ILIKE 'john%'))
      end

      it "supports like with complex patterns" do
        r = Lustra::SQL.select.from(:users).where { users.email.like("user%@%.com") }
        r.to_sql.should eq %(SELECT * FROM "users" WHERE ("users"."email" LIKE 'user%@%.com'))
      end

      it "supports ilike with complex patterns" do
        r = Lustra::SQL.select.from(:users).where { users.email.ilike("user%@%.com") }
        r.to_sql.should eq %(SELECT * FROM "users" WHERE ("users"."email" ILIKE 'user%@%.com'))
      end
    end

    describe "regex operators" do
      it "supports =~ operator with Node" do
        r = Lustra::SQL.select.from(:users).where { users.email =~ users.pattern }
        r.to_sql.should eq %(SELECT * FROM "users" WHERE ("users"."email" ~ "users"."pattern"))
      end

      it "supports !~ operator with Node" do
        r = Lustra::SQL.select.from(:users).where { users.email !~ users.pattern }
        r.to_sql.should eq %(SELECT * FROM "users" WHERE ("users"."email" !~ "users"."pattern"))
      end

      it "supports =~ operator with Regex (case sensitive)" do
        r = Lustra::SQL.select.from(:users).where { users.email =~ /^[a-z]+@/ }
        r.to_sql.should eq %(SELECT * FROM "users" WHERE ("users"."email" ~ '^[a-z]+@'))
      end

      it "supports =~ operator with Regex (case insensitive)" do
        r = Lustra::SQL.select.from(:users).where { users.email =~ /^[a-z]+@/i }
        r.to_sql.should eq %(SELECT * FROM "users" WHERE ("users"."email" ~* '^[a-z]+@'))
      end

      it "supports !~ operator with Regex (case sensitive)" do
        r = Lustra::SQL.select.from(:users).where { users.email !~ /^[a-z]+@/ }
        r.to_sql.should eq %(SELECT * FROM "users" WHERE ("users"."email" !~ '^[a-z]+@'))
      end

      it "supports !~ operator with Regex (case insensitive)" do
        r = Lustra::SQL.select.from(:users).where { users.email !~ /^[a-z]+@/i }
        r.to_sql.should eq %(SELECT * FROM "users" WHERE ("users"."email" !~* '^[a-z]+@'))
      end
    end

    describe "unary operators" do
      it "supports unary NOT operator" do
        r = Lustra::SQL.select.from(:users).where { ~users.active }
        r.to_sql.should eq %(SELECT * FROM "users" WHERE NOT "users"."active")
      end

      it "supports unary NOT with complex expressions" do
        r = Lustra::SQL.select.from(:users).where { ~(users.id > 100) }
        r.to_sql.should eq %(SELECT * FROM "users" WHERE NOT ("users"."id" > 100))
      end
    end
  end
end
