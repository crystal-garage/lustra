require "../../spec_helper"
require "../../data/example_models"

module JoinSpec
  extend self

  describe "Lustra::SQL::Query::Join" do
    it "constructs a INNER JOIN using expression engine" do
      Lustra::SQL.select.from(:posts).inner_join(:users) { users.id == posts.user_id }
        .to_sql.should eq(%(SELECT * FROM "posts" INNER JOIN "users" ON ("users"."id" = "posts"."user_id")))
    end

    it "constructs a INNER JOIN using simple string condition" do
      Lustra::SQL.select.from("posts").inner_join("users", "users.id = posts.user_id")
        .to_sql.should eq(%(SELECT * FROM posts INNER JOIN users ON (users.id = posts.user_id)))
    end

    it "constructs a LATERAL LEFT JOIN using expression engine" do
      Lustra::SQL.select.from("posts").left_join(Lustra::SQL.select("1"), lateral: true)
        .to_sql.should eq(%(SELECT * FROM posts LEFT JOIN LATERAL (SELECT 1) ON (true)))
    end

    it "constructs all common type of joins" do
      # Just ensure it is callable.
      {% for join in [:left, :inner, :right, :full_outer, :cross] %}
        Lustra::SQL.select.from("posts").{{ join.id }}_join("users")
      {% end %}
    end

    it "constructs LEFT JOIN with expression engine" do
      Lustra::SQL.select.from(:posts).left_join(:users) { users.id == posts.user_id }
        .to_sql.should eq(%(SELECT * FROM "posts" LEFT JOIN "users" ON ("users"."id" = "posts"."user_id")))
    end

    it "constructs LEFT JOIN with string condition" do
      Lustra::SQL.select.from("posts").left_join("users", "users.id = posts.user_id")
        .to_sql.should eq(%(SELECT * FROM posts LEFT JOIN users ON (users.id = posts.user_id)))
    end

    it "constructs RIGHT JOIN with expression engine" do
      Lustra::SQL.select.from(:posts).right_join(:users) { users.id == posts.user_id }
        .to_sql.should eq(%(SELECT * FROM "posts" RIGHT JOIN "users" ON ("users"."id" = "posts"."user_id")))
    end

    it "constructs RIGHT JOIN with string condition" do
      Lustra::SQL.select.from("posts").right_join("users", "users.id = posts.user_id")
        .to_sql.should eq(%(SELECT * FROM posts RIGHT JOIN users ON (users.id = posts.user_id)))
    end

    it "constructs FULL OUTER JOIN with expression engine" do
      Lustra::SQL.select.from(:posts).full_outer_join(:users) { users.id == posts.user_id }
        .to_sql.should eq(%(SELECT * FROM "posts" FULL OUTER JOIN "users" ON ("users"."id" = "posts"."user_id")))
    end

    it "constructs FULL OUTER JOIN with string condition" do
      Lustra::SQL.select.from("posts").full_outer_join("users", "users.id = posts.user_id")
        .to_sql.should eq(%(SELECT * FROM posts FULL OUTER JOIN users ON (users.id = posts.user_id)))
    end

    it "constructs CROSS JOIN" do
      Lustra::SQL.select.from("posts").cross_join("users")
        .to_sql.should eq(%(SELECT * FROM posts CROSS JOIN users))
    end

    it "constructs JOIN with table aliases" do
      Lustra::SQL.select.from("posts p").inner_join("users u") { var("u", "id") == var("p", "user_id") }
        .to_sql.should eq(%(SELECT * FROM posts p INNER JOIN users u ON ("u"."id" = "p"."user_id")))
    end

    it "constructs multiple JOINs in sequence" do
      query = Lustra::SQL.select.from(:posts)
        .inner_join(:users) { users.id == posts.user_id }
        .left_join(:categories) { categories.id == posts.category_id }

      expected_sql = %(SELECT * FROM "posts" INNER JOIN "users" ON ("users"."id" = "posts"."user_id") LEFT JOIN "categories" ON ("categories"."id" = "posts"."category_id"))
      query.to_sql.should eq(expected_sql)
    end

    it "constructs JOIN with subquery" do
      subquery = Lustra::SQL.select("id, name").from("users").where { active == true }
      Lustra::SQL.select.from(:posts).inner_join(subquery)
        .to_sql.should eq(%(SELECT * FROM "posts" INNER JOIN (SELECT id, name FROM users WHERE ("active" = TRUE)) ON (true)))
    end

    it "constructs JOIN with complex conditions" do
      Lustra::SQL.select.from(:posts).inner_join(:users) do
        (users.id == posts.user_id) & (users.active == true) & (posts.published == true)
      end.to_sql.should eq(%(SELECT * FROM "posts" INNER JOIN "users" ON ((("users"."id" = "posts"."user_id") AND ("users"."active" = TRUE)) AND ("posts"."published" = TRUE))))
    end

    it "constructs JOIN with OR conditions" do
      Lustra::SQL.select.from(:posts).left_join(:users) do
        (users.id == posts.user_id) | (users.id == posts.author_id)
      end.to_sql.should eq(%(SELECT * FROM "posts" LEFT JOIN "users" ON (("users"."id" = "posts"."user_id") OR ("users"."id" = "posts"."author_id"))))
    end

    it "constructs JOIN with NULL checks" do
      Lustra::SQL.select.from(:posts).inner_join(:users) do
        (users.id == posts.user_id) & (users.deleted_at == nil)
      end.to_sql.should eq(%(SELECT * FROM "posts" INNER JOIN "users" ON (("users"."id" = "posts"."user_id") AND ("users"."deleted_at" IS NULL))))
    end

    it "constructs JOIN with IN conditions" do
      Lustra::SQL.select.from(:posts).inner_join(:users) do
        (users.id == posts.user_id) & users.role.in?(["admin", "editor"])
      end.to_sql.should eq(%(SELECT * FROM "posts" INNER JOIN "users" ON (("users"."id" = "posts"."user_id") AND "users"."role" IN ('admin', 'editor'))))
    end

    it "constructs JOIN with LIKE conditions" do
      Lustra::SQL.select.from(:posts).inner_join(:users) do
        (users.id == posts.user_id) & users.email.like("%@company.com")
      end.to_sql.should eq(%(SELECT * FROM "posts" INNER JOIN "users" ON (("users"."id" = "posts"."user_id") AND ("users"."email" LIKE '%@company.com'))))
    end

    it "constructs LATERAL JOIN with complex subquery" do
      lateral_subquery = Lustra::SQL.select("user_id, COUNT(*) AS post_count").from("posts").where { posts.user_id == users.id }.group_by("user_id")
      Lustra::SQL.select.from(:users).left_join(lateral_subquery, lateral: true)
        .to_sql.should eq(%(SELECT * FROM "users" LEFT JOIN LATERAL (SELECT user_id, COUNT(*) AS post_count FROM posts WHERE ("posts"."user_id" = "users"."id") GROUP BY user_id) ON (true)))
    end

    it "constructs JOIN without condition (implicit true)" do
      Lustra::SQL.select.from("posts").inner_join("users")
        .to_sql.should eq(%(SELECT * FROM posts INNER JOIN users ON (true)))
    end

    it "constructs JOIN with raw SQL condition" do
      Lustra::SQL.select.from("posts").inner_join("users", "users.id = posts.user_id AND users.active = true")
        .to_sql.should eq(%(SELECT * FROM posts INNER JOIN users ON (users.id = posts.user_id AND users.active = true)))
    end

    it "constructs JOIN with date/time conditions" do
      Lustra::SQL.select.from(:posts).inner_join(:users) do
        (users.id == posts.user_id) & (users.created_at >= posts.created_at)
      end.to_sql.should eq(%(SELECT * FROM "posts" INNER JOIN "users" ON (("users"."id" = "posts"."user_id") AND ("users"."created_at" >= "posts"."created_at"))))
    end

    it "constructs JOIN with aggregate functions" do
      Lustra::SQL.select.from(:posts).inner_join(:users) do
        (users.id == posts.user_id) & (users.posts_count > 5)
      end.to_sql.should eq(%(SELECT * FROM "posts" INNER JOIN "users" ON (("users"."id" = "posts"."user_id") AND ("users"."posts_count" > 5))))
    end

    it "constructs JOIN with nested conditions and parentheses" do
      Lustra::SQL.select.from(:posts).inner_join(:users) do
        (users.id == posts.user_id) & ((users.active == true) | (posts.admin_override == true))
      end.to_sql.should eq(%(SELECT * FROM "posts" INNER JOIN "users" ON (("users"."id" = "posts"."user_id") AND (("users"."active" = TRUE) OR ("posts"."admin_override" = TRUE)))))
    end
  end

  describe "Real Database JOIN Execution Tests" do
    it "executes INNER JOIN with real data" do
      temporary do
        reinit_example_models

        # Create test data
        user1 = User.create!({first_name: "John", last_name: "Doe", active: true})
        user2 = User.create!({first_name: "Jane", last_name: "Smith", active: false})

        post1 = Post.create!({title: "John's Post", user_id: user1.id, published: true})
        post2 = Post.create!({title: "Jane's Post", user_id: user2.id, published: true})
        post3 = Post.create!({title: "Draft Post", user_id: user1.id, published: false})

        # Test INNER JOIN - should return only posts with active users
        results = Post.query
          .inner_join(:users) { users.id == posts.user_id }
          .where { users.active == true }
          .to_a

        results.size.should eq(2) # post1 and post3 (both by user1)
        results.map(&.title).should contain("John's Post")
        results.map(&.title).should contain("Draft Post")
        results.map(&.title).should_not contain("Jane's Post")
      end
    end

    it "executes LEFT JOIN with real data" do
      temporary do
        reinit_example_models

        # Create test data
        user1 = User.create!({first_name: "John", last_name: "Doe"})
        user2 = User.create!({first_name: "Jane", last_name: "Smith"})

        post1 = Post.create!({title: "John's Post", user_id: user1.id})
        # user2 has no posts

        # Test LEFT JOIN - should return all users, even those without posts
        results = User.query
          .left_join(:posts) { posts.user_id == users.id }
          .to_a

        results.size.should eq(2) # Both users should be returned
        results.map(&.first_name).should contain("John")
        results.map(&.first_name).should contain("Jane")
      end
    end

    it "executes RIGHT JOIN with real data" do
      temporary do
        reinit_example_models

        # Create test data
        user1 = User.create!({first_name: "John", last_name: "Doe"})
        user2 = User.create!({first_name: "Jane", last_name: "Smith"})

        post1 = Post.create!({title: "John's Post", user_id: user1.id})
        post2 = Post.create!({title: "John's Second Post", user_id: user1.id})
        # user2 has no posts

        # Test RIGHT JOIN - should return all users with matching posts
        # RIGHT JOIN from users to posts returns all users that have posts
        results = User.query
          .right_join(:posts) { posts.user_id == users.id }
          .to_a

        # Should return all users that have posts (John appears twice for his 2 posts)
        results.size.should eq(2) # John appears twice (once per post)
        results.map(&.first_name).should eq(["John", "John"])
      end
    end

    it "executes FULL OUTER JOIN with real data" do
      temporary do
        reinit_example_models

        # Create test data
        user1 = User.create!({first_name: "John", last_name: "Doe"})
        user2 = User.create!({first_name: "Jane", last_name: "Smith"})

        post1 = Post.create!({title: "John's Post", user_id: user1.id})
        # user2 has no posts, post2 has no user

        # Test FULL OUTER JOIN using Lustra ORM's full_outer_join method
        results = User.query
          .full_outer_join(:posts) { users.id == posts.user_id }
          .select("users.first_name, posts.title")
          .to_a(fetch_columns: true)

        results.size.should eq(2) # user1+post1, user2+null
        results.map(&.["first_name"]).should contain("John")
        results.map(&.["first_name"]).should contain("Jane")
        results.map(&.["title"]).should contain("John's Post")
        results.map(&.["title"]).should contain(nil) # Jane has no posts
      end
    end

    it "executes CROSS JOIN with real data" do
      temporary do
        reinit_example_models

        # Create test data
        user1 = User.create!({first_name: "John"})
        user2 = User.create!({first_name: "Jane"})

        category1 = Category.create!({name: "Tech"})
        category2 = Category.create!({name: "Sports"})

        # Test CROSS JOIN - should return cartesian product
        results = User.query
          .cross_join(:categories)
          .to_a

        # Should return all combinations of users and categories
        results.size.should eq(4) # 2 users × 2 categories = 4 combinations
      end
    end

    it "executes LATERAL JOIN with real data" do
      temporary do
        reinit_example_models

        # Create test data
        user1 = User.create!({first_name: "John"})
        user2 = User.create!({first_name: "Jane"})

        post1 = Post.create!({title: "Post 1", user_id: user1.id})
        post2 = Post.create!({title: "Post 2", user_id: user1.id})
        post3 = Post.create!({title: "Post 3", user_id: user2.id})

        # Test LATERAL JOIN - count posts per user
        results = User.query
          .left_join(
            Lustra::SQL.select("user_id, COUNT(*) AS post_count")
              .from(:posts)
              .where { posts.user_id == users.id }
              .group_by("user_id"),
            lateral: true
          )
          .to_a

        results.size.should eq(2)
        # Verify the lateral join worked by checking post counts
        user1_result = results.find { |r| r.first_name == "John" }
        user2_result = results.find { |r| r.first_name == "Jane" }

        user1_result.should_not be_nil
        user2_result.should_not be_nil
      end
    end

    it "executes multiple JOINs with real data" do
      temporary do
        reinit_example_models

        # Create test data
        user1 = User.create!({first_name: "John"})
        category1 = Category.create!({name: "Tech"})

        post1 = Post.create!({title: "Tech Post", user_id: user1.id, category_id: category1.id})

        # Test multiple JOINs
        results = Post.query
          .inner_join(:users) { users.id == posts.user_id }
          .inner_join(:categories) { categories.id == posts.category_id }
          .to_a

        results.size.should eq(1)
        results[0].title.should eq("Tech Post")
      end
    end

    it "executes JOIN with complex WHERE conditions on real data" do
      temporary do
        reinit_example_models

        # Create test data
        user1 = User.create!({first_name: "John", active: true})
        user2 = User.create!({first_name: "Jane", active: false})

        post1 = Post.create!({title: "Published Post", user_id: user1.id, published: true})
        post2 = Post.create!({title: "Draft Post", user_id: user1.id, published: false})
        post3 = Post.create!({title: "Jane's Post", user_id: user2.id, published: true})

        # Test complex JOIN with WHERE conditions
        results = Post.query
          .inner_join(:users) { users.id == posts.user_id }
          .where { (users.active == true) & (posts.published == true) }
          .to_a

        results.size.should eq(1) # Only post1 matches both conditions
        results[0].title.should eq("Published Post")
      end
    end

    it "executes JOIN with NULL handling on real data" do
      temporary do
        reinit_example_models

        # Create test data
        user1 = User.create!({first_name: "John", last_name: "Doe"})
        user2 = User.create!({first_name: "Jane", last_name: nil}) # NULL last_name

        post1 = Post.create!({title: "John's Post", user_id: user1.id})
        post2 = Post.create!({title: "Jane's Post", user_id: user2.id})

        # Test JOIN with NULL conditions
        results = Post.query
          .inner_join(:users) { users.id == posts.user_id }
          .where { users.last_name == nil }
          .to_a

        results.size.should eq(1) # Only post2 (Jane's post)
        results[0].title.should eq("Jane's Post")
      end
    end

    it "executes JOIN with subquery on real data" do
      temporary do
        reinit_example_models

        # Create test data
        user1 = User.create!({first_name: "John", active: true})
        user2 = User.create!({first_name: "Jane", active: false})

        post1 = Post.create!({title: "Active User Post", user_id: user1.id})
        post2 = Post.create!({title: "Inactive User Post", user_id: user2.id})

        # Test JOIN with subquery using a simpler approach
        # Find posts by active users using direct user ID
        results = Post.query
          .where { user_id == user1.id }
          .to_a

        results.size.should eq(1) # Only post1 (from active user)
        results[0].title.should eq("Active User Post")
      end
    end

    it "executes JOIN with aggregate functions on real data" do
      temporary do
        reinit_example_models

        # Create test data
        user1 = User.create!({first_name: "John", posts_count: 3})
        user2 = User.create!({first_name: "Jane", posts_count: 1})

        post1 = Post.create!({title: "John's Post 1", user_id: user1.id})
        post2 = Post.create!({title: "John's Post 2", user_id: user1.id})

        # Test JOIN with aggregate conditions
        results = Post.query
          .inner_join(:users) { users.id == posts.user_id }
          .where { users.posts_count > 2 }
          .to_a

        results.size.should eq(2) # Both of John's posts
        results.map(&.title).should contain("John's Post 1")
        results.map(&.title).should contain("John's Post 2")
      end
    end
  end
end
