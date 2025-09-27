require "../../spec_helper"

module JoinSpec
  extend self

  describe "Clear::SQL::Query::Join" do
    it "constructs a INNER JOIN using expression engine" do
      Clear::SQL.select.from(:posts).inner_join(:users) { users.id == posts.user_id }
        .to_sql.should eq(%(SELECT * FROM "posts" INNER JOIN "users" ON ("users"."id" = "posts"."user_id")))
    end

    it "constructs a INNER JOIN using simple string condition" do
      Clear::SQL.select.from("posts").inner_join("users", "users.id = posts.user_id")
        .to_sql.should eq(%(SELECT * FROM posts INNER JOIN users ON (users.id = posts.user_id)))
    end

    it "constructs a LATERAL LEFT JOIN using expression engine" do
      Clear::SQL.select.from("posts").left_join(Clear::SQL.select("1"), lateral: true)
        .to_sql.should eq(%(SELECT * FROM posts LEFT JOIN LATERAL (SELECT 1) ON (true)))
    end

    it "constructs all common type of joins" do
      # Just ensure it is callable.
      {% for join in [:left, :inner, :right, :full_outer, :cross] %}
        Clear::SQL.select.from("posts").{{join.id}}_join("users")
      {% end %}
    end

    it "constructs LEFT JOIN with expression engine" do
      Clear::SQL.select.from(:posts).left_join(:users) { users.id == posts.user_id }
        .to_sql.should eq(%(SELECT * FROM "posts" LEFT JOIN "users" ON ("users"."id" = "posts"."user_id")))
    end

    it "constructs LEFT JOIN with string condition" do
      Clear::SQL.select.from("posts").left_join("users", "users.id = posts.user_id")
        .to_sql.should eq(%(SELECT * FROM posts LEFT JOIN users ON (users.id = posts.user_id)))
    end

    it "constructs RIGHT JOIN with expression engine" do
      Clear::SQL.select.from(:posts).right_join(:users) { users.id == posts.user_id }
        .to_sql.should eq(%(SELECT * FROM "posts" RIGHT JOIN "users" ON ("users"."id" = "posts"."user_id")))
    end

    it "constructs RIGHT JOIN with string condition" do
      Clear::SQL.select.from("posts").right_join("users", "users.id = posts.user_id")
        .to_sql.should eq(%(SELECT * FROM posts RIGHT JOIN users ON (users.id = posts.user_id)))
    end

    it "constructs FULL OUTER JOIN with expression engine" do
      Clear::SQL.select.from(:posts).full_outer_join(:users) { users.id == posts.user_id }
        .to_sql.should eq(%(SELECT * FROM "posts" FULL OUTER JOIN "users" ON ("users"."id" = "posts"."user_id")))
    end

    it "constructs FULL OUTER JOIN with string condition" do
      Clear::SQL.select.from("posts").full_outer_join("users", "users.id = posts.user_id")
        .to_sql.should eq(%(SELECT * FROM posts FULL OUTER JOIN users ON (users.id = posts.user_id)))
    end

    it "constructs CROSS JOIN" do
      Clear::SQL.select.from("posts").cross_join("users")
        .to_sql.should eq(%(SELECT * FROM posts CROSS JOIN users))
    end

    it "constructs JOIN with table aliases" do
      Clear::SQL.select.from("posts p").inner_join("users u") { var("u", "id") == var("p", "user_id") }
        .to_sql.should eq(%(SELECT * FROM posts p INNER JOIN users u ON ("u"."id" = "p"."user_id")))
    end

    it "constructs multiple JOINs in sequence" do
      query = Clear::SQL.select.from(:posts)
        .inner_join(:users) { users.id == posts.user_id }
        .left_join(:categories) { categories.id == posts.category_id }

      expected_sql = %(SELECT * FROM "posts" INNER JOIN "users" ON ("users"."id" = "posts"."user_id") LEFT JOIN "categories" ON ("categories"."id" = "posts"."category_id"))
      query.to_sql.should eq(expected_sql)
    end

    it "constructs JOIN with subquery" do
      subquery = Clear::SQL.select("id, name").from("users").where { active == true }
      Clear::SQL.select.from(:posts).inner_join(subquery)
        .to_sql.should eq(%(SELECT * FROM "posts" INNER JOIN (SELECT id, name FROM users WHERE ("active" = TRUE)) ON (true)))
    end

    it "constructs JOIN with complex conditions" do
      Clear::SQL.select.from(:posts).inner_join(:users) do
        (users.id == posts.user_id) & (users.active == true) & (posts.published == true)
      end.to_sql.should eq(%(SELECT * FROM "posts" INNER JOIN "users" ON ((("users"."id" = "posts"."user_id") AND ("users"."active" = TRUE)) AND ("posts"."published" = TRUE))))
    end

    it "constructs JOIN with OR conditions" do
      Clear::SQL.select.from(:posts).left_join(:users) do
        (users.id == posts.user_id) | (users.id == posts.author_id)
      end.to_sql.should eq(%(SELECT * FROM "posts" LEFT JOIN "users" ON (("users"."id" = "posts"."user_id") OR ("users"."id" = "posts"."author_id"))))
    end

    it "constructs JOIN with NULL checks" do
      Clear::SQL.select.from(:posts).inner_join(:users) do
        (users.id == posts.user_id) & (users.deleted_at == nil)
      end.to_sql.should eq(%(SELECT * FROM "posts" INNER JOIN "users" ON (("users"."id" = "posts"."user_id") AND ("users"."deleted_at" IS NULL))))
    end

    it "constructs JOIN with IN conditions" do
      Clear::SQL.select.from(:posts).inner_join(:users) do
        (users.id == posts.user_id) & users.role.in?(["admin", "editor"])
      end.to_sql.should eq(%(SELECT * FROM "posts" INNER JOIN "users" ON (("users"."id" = "posts"."user_id") AND "users"."role" IN ('admin', 'editor'))))
    end

    it "constructs JOIN with LIKE conditions" do
      Clear::SQL.select.from(:posts).inner_join(:users) do
        (users.id == posts.user_id) & users.email.like("%@company.com")
      end.to_sql.should eq(%(SELECT * FROM "posts" INNER JOIN "users" ON (("users"."id" = "posts"."user_id") AND ("users"."email" LIKE '%@company.com'))))
    end

    it "constructs LATERAL JOIN with complex subquery" do
      lateral_subquery = Clear::SQL.select("user_id, COUNT(*) as post_count").from("posts").where { posts.user_id == users.id }.group_by("user_id")
      Clear::SQL.select.from(:users).left_join(lateral_subquery, lateral: true)
        .to_sql.should eq(%(SELECT * FROM "users" LEFT JOIN LATERAL (SELECT user_id, COUNT(*) as post_count FROM posts WHERE ("posts"."user_id" = "users"."id") GROUP BY user_id) ON (true)))
    end

    it "constructs JOIN without condition (implicit true)" do
      Clear::SQL.select.from("posts").inner_join("users")
        .to_sql.should eq(%(SELECT * FROM posts INNER JOIN users ON (true)))
    end

    it "constructs JOIN with raw SQL condition" do
      Clear::SQL.select.from("posts").inner_join("users", "users.id = posts.user_id AND users.active = true")
        .to_sql.should eq(%(SELECT * FROM posts INNER JOIN users ON (users.id = posts.user_id AND users.active = true)))
    end

    it "constructs JOIN with date/time conditions" do
      Clear::SQL.select.from(:posts).inner_join(:users) do
        (users.id == posts.user_id) & (users.created_at >= posts.created_at)
      end.to_sql.should eq(%(SELECT * FROM "posts" INNER JOIN "users" ON (("users"."id" = "posts"."user_id") AND ("users"."created_at" >= "posts"."created_at"))))
    end

    it "constructs JOIN with aggregate functions" do
      Clear::SQL.select.from(:posts).inner_join(:users) do
        (users.id == posts.user_id) & (users.posts_count > 5)
      end.to_sql.should eq(%(SELECT * FROM "posts" INNER JOIN "users" ON (("users"."id" = "posts"."user_id") AND ("users"."posts_count" > 5))))
    end

    it "constructs JOIN with nested conditions and parentheses" do
      Clear::SQL.select.from(:posts).inner_join(:users) do
        (users.id == posts.user_id) & ((users.active == true) | (posts.admin_override == true))
      end.to_sql.should eq(%(SELECT * FROM "posts" INNER JOIN "users" ON (("users"."id" = "posts"."user_id") AND (("users"."active" = TRUE) OR ("posts"."admin_override" = TRUE)))))
    end
  end
end
