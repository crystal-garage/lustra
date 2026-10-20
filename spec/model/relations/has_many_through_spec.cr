require "../../spec_helper"
require "../../data/example_models"

describe "Lustra::Model::Relations::HasManyThrough" do
  context "Post -> Tag through PostTag" do
    describe "basic operations" do
      it "starts with empty tag relations" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          post = Post.create!({title: "Test Post", user_id: user.id})

          post.tags.count.should eq(0)
          post.tags.empty?.should be_true
        end
      end

      it "adds tags using << and creates their PostTag records" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          post = Post.create!({title: "Test Post", user_id: user.id})
          tag1 = Tag.create!({name: "Ruby"})
          tag2 = Tag.create!({name: "Crystal"})
          tag3 = Tag.create!({name: "Programming"})

          post.tags << tag1

          PostTag.query.count.should eq(1)
          post.tags.count.should eq(1)
          post.tags.first!.name.should eq("Ruby")

          post.tags << tag2
          post.tags << tag3

          post.tags.count.should eq(3)
          post.tags.map(&.name).should contain("Ruby")
          post.tags.map(&.name).should contain("Crystal")
          post.tags.map(&.name).should contain("Programming")

          Tag.query.count.should eq(3)
          PostTag.query.count.should eq(3)
          {tag1, tag2, tag3}.each do |tag|
            PostTag.query.find_by({post_id: post.id, tag_id: tag.id}).should_not be_nil
          end
        end
      end

      it "can remove tags using unlink" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          post = Post.create!({title: "Test Post", user_id: user.id})
          tag1 = Tag.new({name: "Ruby"})
          tag2 = Tag.new({name: "Crystal"})
          tag3 = Tag.new({name: "Programming"})

          post.tags << tag1
          post.tags << tag2
          post.tags << tag3

          post.tags.count.should eq(3)
          post.tags.unlink(Tag.query.find_by!({name: "Crystal"}))

          post.tags.count.should eq(2)
          post.tags.map(&.name).should contain("Ruby")
          post.tags.map(&.name).should contain("Programming")
          post.tags.map(&.name).should_not contain("Crystal")
        end
      end

      it "removes PostTag records when unlinking tags" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          post = Post.create!({title: "Test Post", user_id: user.id})
          tag1 = Tag.create!({name: "Ruby"})
          tag2 = Tag.create!({name: "Crystal"})

          post.tags << tag1
          post.tags << tag2

          post.tags.unlink(tag1)

          PostTag.query.where({post_id: post.id}).count.should eq(1)
          PostTag.query.find_by({post_id: post.id, tag_id: tag1.id}).should be_nil
        end
      end

      it "can clear all tags" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          post = Post.create!({title: "Test Post", user_id: user.id})
          tag1 = Tag.create!({name: "Ruby"})
          tag2 = Tag.create!({name: "Crystal"})
          tag3 = Tag.create!({name: "Programming"})

          post.tags << tag1
          post.tags << tag2
          post.tags << tag3

          # Unlink each tag individually (delete_all doesn't work correctly for has_many through)
          post.tags.each do |tag|
            post.tags.unlink(tag)
          end

          post.tags.count.should eq(0)
          PostTag.query.where({post_id: post.id}).count.should eq(0)
        end
      end
    end

    describe "querying through relationships" do
      it "can filter tags by name" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          post = Post.create!({title: "Test Post", user_id: user.id})
          tag1 = Tag.create!({name: "Ruby"})
          tag2 = Tag.create!({name: "Crystal"})
          tag3 = Tag.create!({name: "Programming"})

          post.tags << tag1
          post.tags << tag2
          post.tags << tag3

          ruby_tags = post.tags.where { name == "Ruby" }
          ruby_tags.count.should eq(1)
          ruby_tags.first!.name.should eq("Ruby")
        end
      end

      it "can use limit and offset" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          post = Post.create!({title: "Test Post", user_id: user.id})
          tag1 = Tag.create!({name: "Ruby"})
          tag2 = Tag.create!({name: "Crystal"})
          tag3 = Tag.create!({name: "Programming"})

          post.tags << tag1
          post.tags << tag2
          post.tags << tag3

          first_tag = post.tags.limit(1).first!
          second_tag = post.tags.offset(1).limit(1).first!

          first_tag.should_not eq(second_tag)
          first_tag.name.should eq("Ruby")
          second_tag.name.should eq("Crystal")
        end
      end

      it "can get all tags" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          post = Post.create!({title: "Test Post", user_id: user.id})
          tag1 = Tag.create!({name: "Ruby"})
          tag2 = Tag.create!({name: "Crystal"})
          tag3 = Tag.create!({name: "Programming"})

          post.tags << tag1
          post.tags << tag2
          post.tags << tag3

          all_tags = post.tags
          all_names = all_tags.map(&.name)

          all_names.should contain("Ruby")
          all_names.should contain("Crystal")
          all_names.should contain("Programming")
          all_names.size.should eq(3)
        end
      end

      it "can check if tag exists" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          post = Post.create!({title: "Test Post", user_id: user.id})
          tag1 = Tag.create!({name: "Ruby"})
          tag2 = Tag.create!({name: "Crystal"})

          post.tags << tag1
          post.tags << tag2

          post.tags.where({name: "Ruby"}).count.should eq(1)
          post.tags.where({name: "NonExistent"}).count.should eq(0)
        end
      end

      it "can find tags" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          post = Post.create!({title: "Test Post", user_id: user.id})
          tag1 = Tag.create!({name: "Ruby"})
          tag2 = Tag.create!({name: "Crystal"})

          post.tags << tag1
          post.tags << tag2

          ruby_tag = post.tags.find_by!({name: "Ruby"})
          ruby_tag.name.should eq("Ruby")

          expect_raises(Lustra::SQL::RecordNotFoundError) do
            post.tags.find_by!({name: "NonExistent"})
          end
        end
      end
    end

    describe "multiple posts and tags" do
      it "each post has independent tag collections" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          post = Post.create!({title: "Test Post", user_id: user.id})
          post2 = Post.create!({title: "Another Post", user_id: user.id})
          tag1 = Tag.create!({name: "Ruby"})
          tag2 = Tag.create!({name: "Crystal"})
          tag3 = Tag.create!({name: "Programming"})
          tag4 = Tag.create!({name: "Database"})

          post.tags << tag1
          post.tags << tag2
          post2.tags << tag2
          post2.tags << tag3
          post2.tags << tag4

          post.tags.count.should eq(2)
          post2.tags.count.should eq(3)

          post.tags.map(&.name).should contain("Ruby")
          post.tags.map(&.name).should contain("Crystal")
          post2.tags.map(&.name).should contain("Crystal")
          post2.tags.map(&.name).should contain("Programming")
          post2.tags.map(&.name).should contain("Database")
        end
      end

      it "can share tags between posts" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          post = Post.create!({title: "Test Post", user_id: user.id})
          post2 = Post.create!({title: "Another Post", user_id: user.id})
          tag2 = Tag.create!({name: "Crystal"})

          post.tags << tag2
          post2.tags << tag2

          # Both posts should have the same tag (by ID)
          post.tags.find_by!({name: "Crystal"}).id.should eq(post2.tags.find_by!({name: "Crystal"}).id)

          # But PostTag records should be separate
          PostTag.query.count.should eq(2)
        end
      end
    end

    describe "Tag -> Post through PostTag (reverse relationship)" do
      it "can query posts from tag side" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          post = Post.create!({title: "Test Post", user_id: user.id})
          tag1 = Tag.create!({name: "Ruby"})

          post.tags << tag1

          tag1.posts.count.should eq(1)
          tag1.posts.first!.title.should eq("Test Post")
        end
      end

      it "can add posts to tags" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          post = Post.create!({title: "Test Post", user_id: user.id})
          tag1 = Tag.create!({name: "Ruby"})

          post.tags << tag1

          post2 = Post.create!({title: "Second Post", user_id: user.id})

          tag1.posts << post2

          tag1.posts.count.should eq(2)
          tag1.posts.map(&.title).should contain("Test Post")
          tag1.posts.map(&.title).should contain("Second Post")
        end
      end
    end

    describe "edge cases" do
      it "handles adding same tag multiple times" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          post = Post.create!({title: "Test Post", user_id: user.id})
          tag1 = Tag.create!({name: "Ruby"})

          post.tags << tag1
          post.tags << tag1 # Add same tag again

          # Should prevent duplicate associations
          post.tags.count.should eq(1)
          Tag.query.count.should eq(1)
          PostTag.query.count.should eq(1)
          # Should only create one PostTag record (no duplicates)
          PostTag.query.where({post_id: post.id, tag_id: tag1.id}).count.should eq(1)
        end
      end

      it "handles unlinking non-existent tag gracefully" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          post = Post.create!({title: "Test Post", user_id: user.id})
          tag1 = Tag.create!({name: "Ruby"})
          tag2 = Tag.create!({name: "Crystal"})

          post.tags << tag1

          # Try to unlink a tag that's not associated
          post.tags.unlink(tag2)

          # Should still have the original tag
          post.tags.count.should eq(1)
          post.tags.first!.name.should eq("Ruby")
        end
      end

      it "handles adding persisted and new tags" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          post = Post.create!({title: "Test Post", user_id: user.id})
          tag1 = Tag.create!({name: "Ruby"})
          new_tag = Tag.new({name: "New Tag"})

          post.tags << tag1
          post.tags << new_tag

          post.tags.count.should eq(2)
          post.tags.map(&.name).should contain("Ruby")
          post.tags.map(&.name).should contain("New Tag")

          # New tag should be persisted
          new_tag.persisted?.should be_true
        end
      end
    end

    describe "SQL generation" do
      it "generates correct SQL for tags query" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          post = Post.create!({title: "Test Post", user_id: user.id})

          expected_sql = "SELECT DISTINCT ON (\"tags\".\"id\") \"tags\".* " +
                         "FROM \"tags\" " +
                         "INNER JOIN \"post_tags\" ON " +
                         "(\"post_tags\".\"tag_id\" = \"tags\".\"id\") " +
                         "WHERE (\"post_tags\".\"post_id\" = #{post.id})"

          post.tags.to_sql.should eq(expected_sql)
        end
      end

      it "generates correct SQL for posts query from tag" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          post = Post.create!({title: "Test Post", user_id: user.id})
          tag1 = Tag.create!({name: "Ruby"})

          expected_sql = "SELECT DISTINCT ON (\"posts\".\"id\") \"posts\".* " +
                         "FROM \"posts\" " +
                         "INNER JOIN \"post_tags\" ON " +
                         "(\"post_tags\".\"post_id\" = \"posts\".\"id\") " +
                         "WHERE (\"post_tags\".\"tag_id\" = #{tag1.id})"

          tag1.posts.to_sql.should eq(expected_sql)
        end
      end
    end
  end

  context "User -> Category through Post" do
    describe "through relationship with different keys" do
      it "can query categories through posts" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "Jane", last_name: "Smith"})
          category1 = Category.create!({name: "Technology"})
          category2 = Category.create!({name: "Science"})

          Post.create!({title: "Tech Post", user_id: user.id, category_id: category1.id})
          Post.create!({title: "Science Post", user_id: user.id, category_id: category2.id})

          user.categories.count.should eq(2)
          user.categories.map(&.name).should contain("Technology")
          user.categories.map(&.name).should contain("Science")
        end
      end

      it "handles duplicate categories correctly" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "Jane", last_name: "Smith"})
          category1 = Category.create!({name: "Technology"})

          Post.create!({title: "Tech Post 1", user_id: user.id, category_id: category1.id})
          Post.create!({title: "Tech Post 2", user_id: user.id, category_id: category1.id})

          user.categories.to_sql.should eq "SELECT DISTINCT ON (\"categories\".\"id\") \"categories\".* " +
                                           "FROM \"categories\" " +
                                           "INNER JOIN \"posts\" ON " +
                                           "(\"posts\".\"category_id\" = \"categories\".\"id\") " +
                                           "WHERE (\"posts\".\"user_id\" = #{user.id})"

          user.posts << Post.new({title: "Another Tech Post", category_id: category1.id})

          # Should only return unique categories
          user.categories.count.should eq(1)
          user.categories.first!.name.should eq("Technology")
        end
      end

      it "can add categories through posts" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "Jane", last_name: "Smith"})
          category1 = Category.create!({name: "Technology"})
          category2 = Category.create!({name: "Science"})

          Post.create!({title: "New Post", user_id: user.id})

          # Create posts with categories manually since the relationship creates posts without titles
          Post.create!({title: "Tech Post", user_id: user.id, category_id: category1.id})
          Post.create!({title: "Science Post", user_id: user.id, category_id: category2.id})

          user.categories.count.should eq(2)

          # Should have 3 posts total
          Post.query.where({user_id: user.id}).count.should eq(3)
        end
      end
    end
  end

  context "User self-referential through Relationship" do
    describe "self-referential through relationship" do
      it "can create dependencies between users" do
        temporary do
          reinit_example_models

          user1 = User.create!({first_name: "Alice", last_name: "Johnson"})
          user2 = User.create!({first_name: "Bob", last_name: "Wilson"})
          user3 = User.create!({first_name: "Charlie", last_name: "Brown"})

          user1.dependencies << user2

          user1.dependencies.count.should eq(1)
          user2.dependents.count.should eq(1)
          user1.dependencies.map(&.first_name).should eq(["Bob"])
          user2.dependents.map(&.first_name).should eq(["Alice"])

          user1.dependencies << user3

          user1.dependencies.count.should eq(2)
          user1.dependencies.map(&.first_name).should contain("Bob")
          user1.dependencies.map(&.first_name).should contain("Charlie")
        end
      end

      it "creates dependencies through the join model" do
        temporary do
          reinit_example_models

          user1 = User.create!({first_name: "John"})
          user2 = User.create!({first_name: "Jane"})

          Relationship.create!({master: user1, dependency: user2})

          user1.dependencies.count.should eq(1)
          user2.dependents.count.should eq(1)
        end
      end

      it "can query dependents" do
        temporary do
          reinit_example_models

          user1 = User.create!({first_name: "Alice", last_name: "Johnson"})
          user2 = User.create!({first_name: "Bob", last_name: "Wilson"})
          user3 = User.create!({first_name: "Charlie", last_name: "Brown"})

          user2.dependents << user1
          user3.dependents << user1

          user1.dependencies.count.should eq(2)
          user2.dependents.count.should eq(1)
          user3.dependents.count.should eq(1)
        end
      end

      it "can unlink dependencies" do
        temporary do
          reinit_example_models

          user1 = User.create!({first_name: "Alice", last_name: "Johnson"})
          user2 = User.create!({first_name: "Bob", last_name: "Wilson"})
          user3 = User.create!({first_name: "Charlie", last_name: "Brown"})

          user1.dependencies << user2
          user1.dependencies << user3

          user1.dependencies.count.should eq(2)
          user2.dependents.count.should eq(1)
          user1.dependencies.unlink(User.query.find_by!({first_name: "Bob"}))

          user1.dependencies.count.should eq(1)
          user1.dependencies.first!.first_name.should eq("Charlie")
          user2.dependents.count.should eq(0)

          user1.dependencies.unlink(user3)

          user1.dependencies.count.should eq(0)
          user3.dependents.count.should eq(0)
        end
      end

      it "generates correct SQL for self-referential queries" do
        temporary do
          reinit_example_models

          user1 = User.create!({first_name: "Alice", last_name: "Johnson"})
          user2 = User.create!({first_name: "Bob", last_name: "Wilson"})

          user1.dependencies << user2

          expected_sql = "SELECT DISTINCT ON (\"users\".\"id\") \"users\".* " +
                         "FROM \"users\" " +
                         "INNER JOIN \"relationships\" ON " +
                         "(\"relationships\".\"dependency_id\" = \"users\".\"id\") " +
                         "WHERE (\"relationships\".\"master_id\" = #{user1.id})"

          user1.dependencies.to_sql.should eq(expected_sql)
        end
      end
    end
  end

  context "Eager loading with has_many through" do
    describe "eager loading" do
      it "can eager load categories through posts" do
        temporary do
          reinit_example_models

          users = [
            User.create!({first_name: "User1", last_name: "One"}),
            User.create!({first_name: "User2", last_name: "Two"}),
            User.create!({first_name: "User3", last_name: "Three"}),
          ]

          categories = [
            Category.create!({name: "Cat1"}),
            Category.create!({name: "Cat2"}),
          ]

          # Create posts connecting users to categories
          Post.create!({title: "Post 1", user_id: users[0].id, category_id: categories[0].id})
          Post.create!({title: "Post 2", user_id: users[0].id, category_id: categories[1].id})
          Post.create!({title: "Post 3", user_id: users[1].id, category_id: categories[0].id})

          loaded_users = User.query.with_categories

          loaded_users.size.should eq(3)

          # Each user should have their categories loaded without additional queries
          user1 = loaded_users.find! { |u| u.first_name == "User1" }
          user1.categories.count.should eq(2)
          user1.categories.map(&.name).should contain("Cat1")
          user1.categories.map(&.name).should contain("Cat2")

          user2 = loaded_users.find! { |u| u.first_name == "User2" }
          user2.categories.count.should eq(1)
          user2.categories.first!.name.should eq("Cat1")

          user3 = loaded_users.find! { |u| u.first_name == "User3" }
          user3.categories.count.should eq(0)
        end
      end

      it "can use eager loading with custom block filtering" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "Test", last_name: "User"})

          categories = [
            Category.create!({name: "Technology"}),
            Category.create!({name: "Science"}),
          ]

          # Create posts connecting user to categories
          Post.create!({title: "Tech Post", user_id: user.id, category_id: categories[0].id})
          Post.create!({title: "Science Post", user_id: user.id, category_id: categories[1].id})

          # Load user with only Technology category
          loaded_users = User.query.with_categories do |categories_query|
            categories_query.where({name: "Technology"})
          end

          loaded_users.size.should eq(1)
          loaded_user = loaded_users.first!

          # Should only have Technology category loaded
          loaded_user.categories.count.should eq(1)
          loaded_user.categories.first!.name.should eq("Technology")
        end
      end
    end
  end

  # Deduplicate by target identity, not by every selected column.
  # These cases guard against replacing DISTINCT ON with whole-row DISTINCT.
  context "target identity and distinctness" do
    {"raw SQL", "structured column"}.each do |selection|
      it "paginates unique self-referential targets ordered by a computed alias selected as #{selection}" do
        temporary do
          reinit_example_models
          user = User.create!(first_name: "User")
          low = User.create!(first_name: "Low", posts_count: 1)
          high = User.create!(first_name: "High", posts_count: 10)
          [low, high].each do |dependent|
            Relationship.create!(master_id: dependent.id, dependency_id: user.id)
          end

          dependents = user.dependents.with_dependencies.group_by("users.id")
          if selection == "raw SQL"
            dependents.select("COALESCE(users.posts_count, 0) AS dependents_count")
          else
            dependents.select(Lustra::SQL::Column.new("COALESCE(users.posts_count, 0)", "dependents_count"))
          end
          dependents.order_by("dependents_count", :desc).order_by("users.id")

          dependents.count.should eq(2)
          first_page = dependents.dup.paginate(1, 1)
          first_page.total_entries.should eq(2)
          records = first_page.to_a(fetch_columns: true)
          records.map(&.id).should eq([high.id])
          records.first.attributes["dependents_count"].should eq(10)
          records.first.dependencies.map(&.id).should eq([user.id])
          dependents.dup.paginate(2, 1).map(&.id).should eq([low.id])
        end
      end
    end

    {"categories.name", %("categories"."name"), :name}.each do |order_column|
      it "paginates unique targets ordered by a non-primary column before their primary key using #{order_column}" do
        temporary do
          reinit_example_models

          user = User.create!(first_name: "Jane")
          first_category = Category.create!(name: "Alpha")
          second_category = Category.create!(name: "Zulu")
          third_category = Category.create!(name: "Zulu")

          Post.create!(title: "Alpha post", user_id: user.id, category_id: first_category.id)
          2.times { Post.create!(title: "Zulu post", user_id: user.id, category_id: second_category.id) }
          Post.create!(title: "Another Zulu post", user_id: user.id, category_id: third_category.id)

          categories = user.categories.with_posts.with_users
            .order_by(order_column, :desc)
            .order_by("categories.id", :asc)

          first_page = categories.dup.paginate(1, 2)
          first_page.total_entries.should eq(3)
          first_page.total_pages.should eq(2)
          first_page.next_page.should eq(2)

          records = first_page.to_a
          records.map(&.id).should eq([second_category.id, third_category.id])
          records.map(&.posts.count).should eq([2, 1])
          records.each(&.users.map(&.id).should(eq([user.id])))

          second_page = categories.dup.paginate(2, 2)
          second_page.total_entries.should eq(3)
          second_page.next_page.should be_nil
          second_page.map(&.id).should eq([first_category.id])

          categories.dup.clear_distinct.count.should eq(4)
          categories.dup.distinct.count.should eq(3)
        end
      end
    end

    it "preserves an explicit DISTINCT ON clause when ordering by a target column" do
      categories = User.new({id: 1_i64}).categories.order_by("categories.name", :desc)

      categories.distinct("categories.id").to_sql.should contain("SELECT DISTINCT ON (categories.id)")
    end

    {"derived table", "CTE", "CTE column list"}.each do |source_kind|
      it "preserves target identity when a #{source_kind} replaces the model table" do
        temporary do
          reinit_example_models
          user = User.create!(first_name: "User")
          category = Category.create!(name: "Original")
          Post.create!(title: "Post", user_id: user.id, category_id: category.id)

          values = "VALUES (#{category.id}, 'Alpha'), (#{category.id}, 'Zulu')"
          categories = user.categories
          case source_kind
          when "derived table"
            categories.clear_from.from("(#{values}) AS categories(id, name)")
          when "CTE"
            categories.with_cte("categories", "SELECT * FROM (#{values}) AS source(id, name)")
          when "CTE column list"
            categories.with_cte("categories(id, name)", values)
          end
          categories.order_by("categories.name").order_by("categories.id")
          categories.to_sql.should contain(%(DISTINCT ON ("categories"."id")))
          categories.clear_order_bys.order_by("categories.id").order_by("categories.name")

          categories.map { |record| {record.id, record.name} }.should eq([{category.id, "Alpha"}])
          categories.count.should eq(1)
          categories.dup.clear_distinct.count.should eq(2)
        end
      end
    end

    it "preserves target identity when an outer CTE shadows the model table" do
      temporary do
        reinit_example_models
        user = User.create!(first_name: "User")
        category = Category.create!(name: "Original")
        Post.create!(title: "Post", user_id: user.id, category_id: category.id)

        categories = user.categories.order_by("categories.id").order_by("categories.name")
        values = "VALUES (#{category.id}, 'Alpha'), (#{category.id}, 'Zulu')"
        query = Lustra::SQL.select("source.id", "source.name")
          .with_cte("categories", "SELECT * FROM (#{values}) AS records(id, name)")
          .from({source: categories})

        query.to_a.map { |row| {row["id"], row["name"]} }.should eq([{category.id, "Alpha"}])
        query.count.should eq(1)
      end
    end

    it "preserves target identity with non-primary ordering inside an outer shadowing CTE" do
      temporary do
        reinit_example_models
        user = User.create!(first_name: "User")
        category = Category.create!(name: "Original")
        Post.create!(title: "Post", user_id: user.id, category_id: category.id)

        categories = user.categories.order_by("categories.name").order_by("categories.id")
        values = "VALUES (#{category.id}, 'Alpha'), (#{category.id}, 'Zulu')"
        query = Lustra::SQL.select("source.id", "source.name")
          .with_cte("categories", "SELECT * FROM (#{values}) AS records(id, name)")
          .from({source: categories})

        query.to_a.map { |row| {row["id"], row["name"]} }.should eq([{category.id, "Alpha"}])
        query.count.should eq(1)
      end
    end

    it "preserves target identity when an unquoted selected alias folds to a target column name" do
      temporary do
        reinit_example_models
        user = User.create!(first_name: "User")
        category = Category.create!(name: "Original")
        Post.create!(title: "Alpha", user_id: user.id, category_id: category.id)
        Post.create!(title: "Zulu", user_id: user.id, category_id: category.id)

        categories = user.categories.clear_select
          .select(Lustra::SQL::Column.new("categories.id", "id"))
          .select(Lustra::SQL::Column.new("posts.title", "NAME"))
          .order_by(:name).order_by("categories.id")

        categories.map { |record| {record.id, record.name} }.should eq([{category.id, "Alpha"}])
        categories.count.should eq(1)
      end
    end

    it "does not rebind qualified ordering to a different selected expression" do
      categories = User.new({id: 1_i64}).categories.clear_select
        .select(Lustra::SQL::Column.new("categories.id", "id"))
        .select(Lustra::SQL::Column.new("posts.title", "name"))
        .order_by("categories.name").order_by("categories.id")

      categories.to_sql.should start_with(%(SELECT DISTINCT ON ("categories"."id")))
    end

    it "does not move an unselected ordering column outside its source scope" do
      categories = User.new({id: 1_i64}).categories.clear_select
        .select(Lustra::SQL::Column.new("categories.id", "id"))
        .order_by(:name).order_by("categories.id")

      categories.to_sql.should start_with(%(SELECT DISTINCT ON ("categories"."id")))
    end

    it "allows duplicate targets after clearing implicit or explicit distinctness" do
      temporary do
        reinit_example_models

        user = User.create!({first_name: "Jane", last_name: "Smith"})
        category = Category.create!({name: "Technology"})
        2.times { Post.create!({title: "Post", user_id: user.id, category_id: category.id}) }

        categories = user.categories
        categories.map(&.id).should eq([category.id])
        categories.clear_distinct.map(&.id).should eq([category.id, category.id])
        categories.distinct.map(&.id).should eq([category.id])
        categories.clear_distinct.map(&.id).should eq([category.id, category.id])
      end
    end

    it "counts and paginates duplicate through rows after clear_distinct" do
      temporary do
        reinit_example_models

        user = User.create!({first_name: "Jane", last_name: "Smith"})
        category = Category.create!({name: "Technology"})
        Post.create!({title: "First", user_id: user.id, category_id: category.id})
        Post.create!({title: "Second", user_id: user.id, category_id: category.id})

        categories = user.categories.clear_distinct
          .select("posts.title AS post_title").order_by("posts.title")
        categories.count.should eq(2)

        first_page = categories.dup.paginate(1, 1)
        first_page.total_entries.should eq(2)
        first_page.total_pages.should eq(2)
        first_page.next_page.should eq(2)
        first_page.map(fetch_columns: true) { |row| {row.id, row.attributes["post_title"]} }
          .should eq([{category.id, "First"}])

        second_page = categories.dup.paginate(2, 1)
        second_page.next_page.should be_nil
        second_page.map(fetch_columns: true) { |row| {row.id, row.attributes["post_title"]} }
          .should eq([{category.id, "Second"}])
      end
    end

    it "preserves duplicate targets when clear_distinct is used in the eager-loading scope" do
      temporary do
        reinit_example_models

        user = User.create!({first_name: "Jane", last_name: "Smith"})
        category = Category.create!({name: "Technology"})
        2.times { Post.create!({title: "Post", user_id: user.id, category_id: category.id}) }

        loaded_user = User.query.with_categories(&.clear_distinct).find!(user.id)

        loaded_user.categories.count.should eq(2)
        loaded_user.categories.map(&.id).should eq([category.id, category.id])
      end
    end

    it "loads targets containing a PostgreSQL point column" do
      temporary do
        reinit_example_models

        # The wildcard selection includes database columns even when the model
        # does not map them explicitly.
        Lustra::SQL.execute("ALTER TABLE categories ADD COLUMN coordinates point DEFAULT point(1, 2)")
        user = User.create!({first_name: "Jane", last_name: "Smith"})
        category = Category.create!({name: "Technology"})
        2.times { Post.create!({title: "Post", user_id: user.id, category_id: category.id}) }

        user.categories.map(&.id).should eq([category.id])
      end
    end

    it "returns one target when selecting different through-table values" do
      temporary do
        reinit_example_models

        user = User.create!({first_name: "Jane", last_name: "Smith"})
        category = Category.create!({name: "Technology"})
        Post.create!({title: "First", user_id: user.id, category_id: category.id})
        Post.create!({title: "Second", user_id: user.id, category_id: category.id})

        categories = user.categories.select("posts.title AS post_title")
          .order_by("categories.id").order_by("posts.title")

        categories.map(fetch_columns: true) { |row| {row.id, row.attributes["post_title"]} }
          .should eq([{category.id, "First"}])
      end
    end

    it "counts and paginates targets rather than distinct through-table projections" do
      temporary do
        reinit_example_models

        user = User.create!({first_name: "Jane", last_name: "Smith"})
        category = Category.create!({name: "Technology"})
        Post.create!({title: "First", user_id: user.id, category_id: category.id})
        Post.create!({title: "Second", user_id: user.id, category_id: category.id})

        categories = user.categories.select("posts.title AS post_title")
          .order_by("categories.id").order_by("posts.title").paginate(1, 1)

        categories.total_entries.should eq(1)
        categories.total_pages.should eq(1)
        categories.next_page.should be_nil
      end
    end

    it "orders by an unselected through-table column after the target primary key" do
      temporary do
        reinit_example_models

        user = User.create!({first_name: "Jane", last_name: "Smith"})
        category = Category.create!({name: "Technology"})
        Post.create!({title: "First", user_id: user.id, category_id: category.id})
        Post.create!({title: "Second", user_id: user.id, category_id: category.id})

        user.categories.order_by("categories.id").order_by("posts.title")
          .map(&.id).should eq([category.id])
      end
    end
  end
end
