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
  end
end
