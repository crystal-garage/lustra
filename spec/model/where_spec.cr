require "../spec_helper"
require "../data/example_models"

module WhereSpec
  describe "execution of WHERE operators" do
    it "comparison operators" do
      temporary do
        reinit_example_models

        User.create!(first_name: "Alice", posts_count: 5)
        User.create!(first_name: "Bob", posts_count: 10)
        User.create!(first_name: "Charlie", posts_count: 15)
        User.create!(first_name: "Diana", posts_count: 20)

        # Test > operator
        users = User.query.where { posts_count > 10 }
        users.size.should eq(2)
        users.map(&.first_name).should contain("Charlie")
        users.map(&.first_name).should contain("Diana")

        # Test >= operator
        users = User.query.where { posts_count >= 10 }
        users.size.should eq(3)
        users.map(&.first_name).should contain("Bob")
        users.map(&.first_name).should contain("Charlie")
        users.map(&.first_name).should contain("Diana")

        # Test < operator
        users = User.query.where { posts_count < 15 }
        users.size.should eq(2)
        users.map(&.first_name).should contain("Alice")
        users.map(&.first_name).should contain("Bob")

        # Test <= operator
        users = User.query.where { posts_count <= 15 }
        users.size.should eq(3)
        users.map(&.first_name).should contain("Alice")
        users.map(&.first_name).should contain("Bob")
        users.map(&.first_name).should contain("Charlie")

        # Test != operator
        users = User.query.where { posts_count != 10 }
        users.size.should eq(3)
        users.map(&.first_name).should contain("Alice")
        users.map(&.first_name).should contain("Charlie")
        users.map(&.first_name).should contain("Diana")
        users.map(&.first_name).should_not contain("Bob")
      end
    end

    it "arithmetic operators" do
      temporary do
        reinit_example_models

        # Create test users with different scores
        User.create!(first_name: "Alice", posts_count: 10)
        User.create!(first_name: "Bob", posts_count: 15)
        User.create!(first_name: "Charlie", posts_count: 20)

        # Test + operator
        users = User.query.where { posts_count + 5 == 15 }
        users.size.should eq(1)
        users.first!.first_name.should eq("Alice") # 10 + 5 = 15

        # Test - operator
        users = User.query.where { posts_count - 5 == 5 }
        users.size.should eq(1)
        users.first!.first_name.should eq("Alice") # 10 - 5 = 5

        # Test * operator
        users = User.query.where { posts_count * 2 == 40 }
        users.size.should eq(1)
        users.first!.first_name.should eq("Charlie") # 20 * 2 = 40

        # Test / operator
        users = User.query.where { posts_count / 2 == 7 }
        users.size.should eq(1)
        users.first!.first_name.should eq("Bob") # 15 / 2 = 7 (integer division)
      end
    end

    it "logical operators" do
      temporary do
        reinit_example_models

        # Create test users
        User.create!(first_name: "Alice", active: true, posts_count: 5)
        User.create!(first_name: "Bob", active: false, posts_count: 10)
        User.create!(first_name: "Charlie", active: true, posts_count: 15)
        User.create!(first_name: "Diana", active: false, posts_count: 20)

        # Test & (AND) operator
        users = User.query.where { (active == true) & (posts_count > 10) }
        users.size.should eq(1)
        users.first!.first_name.should eq("Charlie")

        # Test | (OR) operator
        users = User.query.where { (active == false) | (posts_count < 10) }
        users.size.should eq(3)
        users.map(&.first_name).should contain("Alice") # active: true, posts_count: 5
        users.map(&.first_name).should contain("Bob")   # active: false
        users.map(&.first_name).should contain("Diana") # active: false
        users.map(&.first_name).should_not contain("Charlie")
      end
    end

    it "pattern matching operators" do
      temporary do
        reinit_example_models

        # Create test users with email-like names
        User.create!(first_name: "john@gmail.com")
        User.create!(first_name: "jane@yahoo.com")
        User.create!(first_name: "bob@company.org")
        User.create!(first_name: "alice@GMAIL.COM")

        # Test like operator (case sensitive)
        users = User.query.where { first_name.like("%@gmail.com") }
        users.size.should eq(1)
        users.first!.first_name.should eq("john@gmail.com")

        # Test ilike operator (case insensitive)
        users = User.query.where { first_name.ilike("%@gmail.com") }
        users.size.should eq(2)
        users.map(&.first_name).should contain("john@gmail.com")
        users.map(&.first_name).should contain("alice@GMAIL.COM")

        # Test like with different patterns
        users = User.query.where { first_name.like("j%") }
        users.size.should eq(2)
        users.map(&.first_name).should contain("john@gmail.com")
        users.map(&.first_name).should contain("jane@yahoo.com")
      end
    end

    it "regex operators" do
      temporary do
        reinit_example_models

        # Create test users with email-like names
        User.create!(first_name: "john@gmail.com")
        User.create!(first_name: "jane@yahoo.com")
        User.create!(first_name: "bob@company.org")
        User.create!(first_name: "alice123@gmail.com")

        # Test =~ operator with regex (case sensitive)
        users = User.query.where { first_name =~ /^[a-z]+@gmail\.com$/ }
        users.size.should eq(1)
        users.first!.first_name.should eq("john@gmail.com")

        # Test =~ operator with regex (case insensitive)
        users = User.query.where { first_name =~ /^[a-z0-9]+@gmail\.com$/i }
        users.size.should eq(2)
        users.map(&.first_name).should contain("john@gmail.com")
        users.map(&.first_name).should contain("alice123@gmail.com")

        # Test !~ operator (does not match)
        users = User.query.where { first_name !~ /@gmail\.com$/ }
        users.size.should eq(2)
        users.map(&.first_name).should contain("jane@yahoo.com")
        users.map(&.first_name).should contain("bob@company.org")
      end
    end

    it "membership operators" do
      temporary do
        reinit_example_models

        # Create test users
        User.create!(first_name: "Alice", posts_count: 5)
        User.create!(first_name: "Bob", posts_count: 10)
        User.create!(first_name: "Charlie", posts_count: 15)
        User.create!(first_name: "Diana", posts_count: 20)

        # Test in? with array
        users = User.query.where { posts_count.in?([5, 15, 25]) }
        users.size.should eq(2)
        users.map(&.first_name).should contain("Alice")
        users.map(&.first_name).should contain("Charlie")

        # Test in? with range
        users = User.query.where { posts_count.in?(10..15) }
        users.size.should eq(2)
        users.map(&.first_name).should contain("Bob")
        users.map(&.first_name).should contain("Charlie")

        # Test in? with exclusive range
        users = User.query.where { posts_count.in?(10...15) }
        users.size.should eq(1)
        users.first!.first_name.should eq("Bob")
      end
    end

    it "between operator" do
      temporary do
        reinit_example_models

        # Create test users
        User.create!(first_name: "Alice", posts_count: 5)
        User.create!(first_name: "Bob", posts_count: 10)
        User.create!(first_name: "Charlie", posts_count: 15)
        User.create!(first_name: "Diana", posts_count: 20)

        # Test between operator
        users = User.query.where { posts_count.between(10, 15) }
        users.size.should eq(2)
        users.map(&.first_name).should contain("Bob")
        users.map(&.first_name).should contain("Charlie")

        # Test between with edge cases
        users = User.query.where { posts_count.between(5, 5) }
        users.size.should eq(1)
        users.first!.first_name.should eq("Alice")
      end
    end

    it "unary operators" do
      temporary do
        reinit_example_models

        # Create test users
        User.create!(first_name: "Alice", active: true)
        User.create!(first_name: "Bob", active: false)
        User.create!(first_name: "Charlie", active: true)

        # Test unary NOT operator
        users = User.query.where { ~active }
        users.size.should eq(1)
        users.first!.first_name.should eq("Bob")

        # Test unary NOT with complex expressions
        users = User.query.where { ~(posts_count > 0) }
        users.size.should eq(3) # All users have posts_count = 0 (default)
        users.map(&.first_name).should contain("Alice")
        users.map(&.first_name).should contain("Bob")
        users.map(&.first_name).should contain("Charlie")
      end
    end

    it "NULL handling" do
      temporary do
        reinit_example_models

        # Create test users with some NULL values
        User.create!(first_name: "Alice", last_name: "Smith")
        User.create!(first_name: "Bob", last_name: nil)
        User.create!(first_name: "Charlie", last_name: "Johnson")

        # Test == nil (IS NULL)
        users = User.query.where { last_name == nil }
        users.size.should eq(1)
        users.first!.first_name.should eq("Bob")

        # Test != nil (IS NOT NULL)
        users = User.query.where { last_name != nil }
        users.size.should eq(2)
        users.map(&.first_name).should contain("Alice")
        users.map(&.first_name).should contain("Charlie")
        users.map(&.first_name).should_not contain("Bob")
      end
    end

    it "complex combinations of operators" do
      temporary do
        reinit_example_models

        # Create test users with various attributes
        User.create!(first_name: "alice@gmail.com", active: true, posts_count: 15)
        User.create!(first_name: "bob@yahoo.com", active: false, posts_count: 5)
        User.create!(first_name: "charlie@gmail.com", active: true, posts_count: 25)
        User.create!(first_name: "diana@company.org", active: true, posts_count: 10)

        # Complex query: active users with gmail addresses and high post counts
        users = User.query.where do
          (active == true) &
            (first_name.ilike("%@gmail.com")) &
            (posts_count > 10)
        end

        users.size.should eq(2)
        users.map(&.first_name).should contain("alice@gmail.com")
        users.map(&.first_name).should contain("charlie@gmail.com")

        # Complex query with arithmetic and regex
        users = User.query.where do
          (posts_count * 2 > 20) &
            (first_name =~ /^[a-z0-9]+@/)
        end

        users.size.should eq(2)
        users.map(&.first_name).should contain("alice@gmail.com")   # 15 * 2 = 30 > 20
        users.map(&.first_name).should contain("charlie@gmail.com") # 25 * 2 = 50 > 20
      end
    end

    describe "WHERE clauses with JOINs" do
      it "WHERE with INNER JOIN" do
        temporary do
          reinit_example_models

          user1 = User.create!(first_name: "John", active: true)
          user2 = User.create!(first_name: "Jane", active: false)
          user3 = User.create!(first_name: "Bob", active: true)

          post1 = Post.create!(title: "John's Post", user_id: user1.id, published: true)
          post2 = Post.create!(title: "Jane's Post", user_id: user2.id, published: true)
          post3 = Post.create!(title: "Bob's Draft", user_id: user3.id, published: false)

          # Test WHERE with INNER JOIN - only posts from active users
          active_user_posts = Post.query
            .inner_join(:users) { users.id == posts.user_id }
            .where { users.active == true }

          active_user_posts.size.should eq(2)
          active_user_posts.map(&.title).should contain("John's Post")
          active_user_posts.map(&.title).should contain("Bob's Draft")
          active_user_posts.map(&.title).should_not contain("Jane's Post")
        end
      end

      it "WHERE with multiple conditions across JOINed tables" do
        temporary do
          reinit_example_models

          user1 = User.create!(first_name: "John", active: true)
          user2 = User.create!(first_name: "Jane", active: true)
          user3 = User.create!(first_name: "Bob", active: false)

          post1 = Post.create!(title: "John's Published Post", user_id: user1.id, published: true)
          post2 = Post.create!(title: "John's Draft", user_id: user1.id, published: false)
          post3 = Post.create!(title: "Jane's Published Post", user_id: user2.id, published: true)
          post4 = Post.create!(title: "Bob's Post", user_id: user3.id, published: true)

          # Test multiple WHERE conditions across JOINed tables
          published_active_posts = Post.query
            .inner_join(:users) { users.id == posts.user_id }
            .where { (users.active == true) & (posts.published == true) }

          published_active_posts.size.should eq(2)
          published_active_posts.map(&.title).should contain("John's Published Post")
          published_active_posts.map(&.title).should contain("Jane's Published Post")
          published_active_posts.map(&.title).should_not contain("John's Draft")
          published_active_posts.map(&.title).should_not contain("Bob's Post")
        end
      end

      it "WHERE with INNER JOIN and NULL handling" do
        temporary do
          reinit_example_models

          user1 = User.create!(first_name: "John", last_name: "Doe")
          user2 = User.create!(first_name: "Jane", last_name: nil) # NULL last_name

          post1 = Post.create!(title: "John's Post", user_id: user1.id)
          post2 = Post.create!(title: "Jane's Post", user_id: user2.id)

          # Test WHERE with INNER JOIN and NULL conditions
          results = Post.query
            .inner_join(:users) { users.id == posts.user_id }
            .where { users.last_name == nil }

          results.size.should eq(1)
          results.first!.title.should eq("Jane's Post")
        end
      end

      it "WHERE with complex JOIN conditions" do
        temporary do
          reinit_example_models

          user1 = User.create!(first_name: "John", active: true)
          user2 = User.create!(first_name: "Jane", active: true)

          category1 = Category.create!(name: "Technology")
          category2 = Category.create!(name: "Science")

          post1 = Post.create!(title: "Tech Post", user_id: user1.id, category_id: category1.id, published: true)
          post2 = Post.create!(title: "Science Post", user_id: user1.id, category_id: category2.id, published: true)
          post3 = Post.create!(title: "Another Tech Post", user_id: user2.id, category_id: category1.id, published: false)

          # Test complex JOIN with WHERE conditions
          results1 = Post.query
            .inner_join(:users) { posts.user_id == users.id }
            .inner_join(:categories) { posts.category_id == categories.id }
            .where do
              (users.active == true) &
                (categories.name == "Technology") &
                (posts.published == true)
            end

          results2 = Post.query
            .inner_join(:user)
            .inner_join(:category)
            .where do
              (users.active == true) &
                (categories.name == "Technology") &
                (posts.published == true)
            end

          results1.to_sql.should eq(results2.to_sql)

          results1.to_sql.should eq(
            "SELECT \"posts\".* FROM \"posts\" INNER JOIN \"users\" ON (\"posts\".\"user_id\" = \"users\".\"id\") INNER JOIN \"categories\" ON (\"posts\".\"category_id\" = \"categories\".\"id\") WHERE (((\"users\".\"active\" = TRUE) AND (\"categories\".\"name\" = 'Technology')) AND (\"posts\".\"published\" = TRUE))"
          )

          results1.size.should eq(1)
          results1.first!.title.should eq("Tech Post")
        end
      end

      it "WHERE with pattern matching in JOINed tables" do
        temporary do
          reinit_example_models

          user1 = User.create!(first_name: "john@gmail.com", active: true)
          user2 = User.create!(first_name: "jane@yahoo.com", active: true)
          user3 = User.create!(first_name: "bob@company.org", active: false)

          post1 = Post.create!(title: "Gmail User's Post", user_id: user1.id)
          post2 = Post.create!(title: "Yahoo User's Post", user_id: user2.id)
          post3 = Post.create!(title: "Company User's Post", user_id: user3.id)

          # Test WHERE with pattern matching in JOINed tables
          results = Post.query
            .inner_join(:users) { users.id == posts.user_id }
            .where { (users.first_name.ilike("%@gmail.com")) & (users.active == true) }

          results.size.should eq(1)
          results.first!.title.should eq("Gmail User's Post")
        end
      end

      it "WHERE with regex in JOINed tables" do
        temporary do
          reinit_example_models

          user1 = User.create!(first_name: "john123@gmail.com", active: true)
          user2 = User.create!(first_name: "jane456@yahoo.com", active: true)
          user3 = User.create!(first_name: "bob@company.org", active: true)

          post1 = Post.create!(title: "Gmail User's Post", user_id: user1.id)
          post2 = Post.create!(title: "Yahoo User's Post", user_id: user2.id)
          post3 = Post.create!(title: "Company User's Post", user_id: user3.id)

          # Test WHERE with regex in JOINed tables
          results = Post.query
            .inner_join(:users) { users.id == posts.user_id }
            .where { (users.first_name =~ /^[a-z0-9]+@gmail\.com$/i) & (users.active == true) }

          results.size.should eq(1)
          results.first!.title.should eq("Gmail User's Post")
        end
      end

      it "WHERE with membership operators in JOINed tables" do
        temporary do
          reinit_example_models

          user1 = User.create!(first_name: "John", active: true)
          user2 = User.create!(first_name: "Jane", active: false)
          user3 = User.create!(first_name: "Bob", active: true)
          user4 = User.create!(first_name: "Alice", active: false)

          post1 = Post.create!(title: "John's Post", user_id: user1.id)
          post2 = Post.create!(title: "Jane's Post", user_id: user2.id)
          post3 = Post.create!(title: "Bob's Post", user_id: user3.id)
          post4 = Post.create!(title: "Alice's Post", user_id: user4.id)

          # Test WHERE with membership operators in JOINed tables
          results = Post.query
            .inner_join(:users) { users.id == posts.user_id }
            .where { users.active.in?([true, nil]) }

          results.size.should eq(2)
          results.map(&.title).should contain("John's Post")      # active: true
          results.map(&.title).should contain("Bob's Post")       # active: true
          results.map(&.title).should_not contain("Jane's Post")  # active: false
          results.map(&.title).should_not contain("Alice's Post") # active: false
        end
      end

      it "WHERE with between operator in JOINed tables" do
        temporary do
          reinit_example_models

          user1 = User.create!(first_name: "John")
          user2 = User.create!(first_name: "Jane")
          user3 = User.create!(first_name: "Bob")
          user4 = User.create!(first_name: "Alice")

          post1 = Post.create!(title: "John's Post", user_id: user1.id)
          post2 = Post.create!(title: "Jane's Post", user_id: user2.id)
          post3 = Post.create!(title: "Bob's Post", user_id: user3.id)
          post4 = Post.create!(title: "Alice's Post", user_id: user4.id)

          # Test WHERE with between operator in JOINed tables using user IDs
          results = Post.query
            .inner_join(:users) { users.id == posts.user_id }
            .where { users.id.between(user2.id, user3.id) }

          results.size.should eq(2)
          results.map(&.title).should contain("Jane's Post")      # user2.id
          results.map(&.title).should contain("Bob's Post")       # user3.id
          results.map(&.title).should_not contain("John's Post")  # user1.id (outside range)
          results.map(&.title).should_not contain("Alice's Post") # user4.id (outside range)
        end
      end

      it "WHERE with complex nested conditions in JOINed tables" do
        temporary do
          reinit_example_models

          user1 = User.create!(first_name: "john@gmail.com", active: true)
          user2 = User.create!(first_name: "jane@yahoo.com", active: true)
          user3 = User.create!(first_name: "bob@gmail.com", active: false)
          user4 = User.create!(first_name: "alice@company.org", active: true)

          post1 = Post.create!(title: "John's Tech Post", user_id: user1.id, published: true)
          post2 = Post.create!(title: "Jane's Post", user_id: user2.id, published: true)
          post3 = Post.create!(title: "Bob's Draft", user_id: user3.id, published: false)
          post4 = Post.create!(title: "Alice's Post", user_id: user4.id, published: true)

          # Test complex nested WHERE conditions in JOINed tables
          results = Post.query
            .inner_join(:users) { users.id == posts.user_id }
            .where do
              ((users.first_name.ilike("%@gmail.com")) & (users.active == true)) |
                ((posts.published == true) & (users.first_name.ilike("%@company.org")))
            end

          results.size.should eq(2)
          results.map(&.title).should contain("John's Tech Post") # gmail + active
          results.map(&.title).should contain("Alice's Post")     # company.org + published
          results.map(&.title).should_not contain("Jane's Post")  # doesn't match either condition
          results.map(&.title).should_not contain("Bob's Draft")  # gmail but inactive + not published
        end
      end
    end
  end
end
