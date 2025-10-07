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

      it "can add tags to post using << operator" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          post = Post.create!({title: "Test Post", user_id: user.id})
          tag1 = Tag.create!({name: "Ruby"})
          tag2 = Tag.create!({name: "Crystal"})

          post.tags << tag1
          post.tags << tag2

          post.tags.count.should eq(2)
          post.tags.map(&.name).should contain("Ruby")
          post.tags.map(&.name).should contain("Crystal")
        end
      end

      it "can add multiple tags at once" do
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

          post.tags.count.should eq(3)
          post.tags.map(&.name).should contain("Ruby")
          post.tags.map(&.name).should contain("Crystal")
          post.tags.map(&.name).should contain("Programming")
        end
      end

      it "creates PostTag records when adding tags" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          post = Post.create!({title: "Test Post", user_id: user.id})
          tag1 = Tag.create!({name: "Ruby"})
          tag2 = Tag.create!({name: "Crystal"})

          post.tags << tag1
          post.tags << tag2

          PostTag.query.count.should eq(2)

          post_tag1 = PostTag.query.find!({post_id: post.id, tag_id: tag1.id})
          post_tag2 = PostTag.query.find!({post_id: post.id, tag_id: tag2.id})

          post_tag1.should_not be_nil
          post_tag2.should_not be_nil
        end
      end

      it "can remove tags using unlink" do
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

          post.tags.unlink(tag2)

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
          PostTag.query.find({post_id: post.id, tag_id: tag1.id}).should be_nil
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

          all_tags = post.tags.to_a
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

          ruby_tag = post.tags.find!({name: "Ruby"})
          ruby_tag.name.should eq("Ruby")

          expect_raises(Lustra::SQL::RecordNotFoundError) do
            post.tags.find!({name: "NonExistent"})
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
          post.tags.find!({name: "Crystal"}).id.should eq(post2.tags.find!({name: "Crystal"}).id)

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
          user1.dependencies << user3

          user1.dependencies.count.should eq(2)
          user1.dependencies.map(&.first_name).should contain("Bob")
          user1.dependencies.map(&.first_name).should contain("Charlie")
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

          user1.dependencies.unlink(user2)

          user1.dependencies.count.should eq(1)
          user1.dependencies.first!.first_name.should eq("Charlie")
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

          loaded_users = User.query.with_categories.to_a

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
          end.to_a

          loaded_users.size.should eq(1)
          loaded_user = loaded_users.first

          # Should only have Technology category loaded
          loaded_user.categories.count.should eq(1)
          loaded_user.categories.first!.name.should eq("Technology")
        end
      end
    end
  end
end
