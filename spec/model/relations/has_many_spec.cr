require "../../spec_helper"
require "../../data/example_models"

describe "Lustra::Model::Relations::HasMany" do
  context "User -> Post relationship" do
    describe "basic operations" do
      it "starts with empty posts collection" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})

          user.posts.count.should eq(0)
          user.posts.empty?.should be_true
        end
      end

      it "can add posts using << operator" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})

          user.posts << Post.new({title: "First Post"})
          user.posts << Post.new({title: "Second Post"})

          user.posts.count.should eq(2)
          user.posts.map(&.title).should contain("First Post")
          user.posts.map(&.title).should contain("Second Post")
        end
      end

      it "can build new posts" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})

          post = user.posts.build({title: "Built Post"})

          post.persisted?.should be_false
          post.user_id.should eq(user.id)
          post.title.should eq("Built Post")

          post.save!
          post.persisted?.should be_true
          user.posts.count.should eq(1)
        end
      end

      it "can create posts directly" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})

          post = user.posts.create!({title: "Created Post"})

          post.persisted?.should be_true
          post.user_id.should eq(user.id)
          post.title.should eq("Created Post")
          user.posts.count.should eq(1)
        end
      end

      it "can query posts with conditions" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          Post.create!({title: "Published Post", user_id: user.id, published: true})
          Post.create!({title: "Draft Post", user_id: user.id, published: false})

          published_posts = user.posts.where({published: true})
          published_posts.count.should eq(1)
          published_posts.first!.title.should eq("Published Post")

          draft_posts = user.posts.where({published: false})
          draft_posts.count.should eq(1)
          draft_posts.first!.title.should eq("Draft Post")
        end
      end

      it "can use limit and offset" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          Post.create!({title: "Post 1", user_id: user.id})
          Post.create!({title: "Post 2", user_id: user.id})
          Post.create!({title: "Post 3", user_id: user.id})

          first_post = user.posts.limit(1).first!
          second_post = user.posts.offset(1).limit(1).first!

          first_post.should_not eq(second_post)
          user.posts.count.should eq(3)
        end
      end

      it "can order posts" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          Post.create!({title: "Charlie Post", user_id: user.id})
          Post.create!({title: "Alpha Post", user_id: user.id})
          Post.create!({title: "Beta Post", user_id: user.id})

          ordered_posts = user.posts.order_by(:title)
          ordered_titles = ordered_posts.map(&.title)

          ordered_titles.should eq(["Alpha Post", "Beta Post", "Charlie Post"])
        end
      end

      it "can check if posts exist" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          Post.create!({title: "Test Post", user_id: user.id})

          user.posts.exists?.should be_true
          user.posts.any?.should be_true
          user.posts.empty?.should be_false
        end
      end

      it "can find posts" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          Post.create!({title: "Find Me", user_id: user.id})

          found_post = user.posts.find!({title: "Find Me"})
          found_post.title.should eq("Find Me")

          expect_raises(Lustra::SQL::RecordNotFoundError) do
            user.posts.find!({title: "Not Found"})
          end
        end
      end

      it "can delete posts" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          post = Post.create!({title: "To Delete", user_id: user.id})

          user.posts.count.should eq(1)

          post.delete

          user.posts.count.should eq(0)
          post.persisted?.should be_false
        end
      end
    end

    describe "multiple users and posts" do
      it "each user has independent post collections" do
        temporary do
          reinit_example_models

          user1 = User.create!({first_name: "John", last_name: "Doe"})
          user2 = User.create!({first_name: "Jane", last_name: "Smith"})

          Post.create!({title: "User1 Post", user_id: user1.id})
          Post.create!({title: "User2 Post", user_id: user2.id})

          user1.posts.count.should eq(1)
          user2.posts.count.should eq(1)

          user1.posts.first!.title.should eq("User1 Post")
          user2.posts.first!.title.should eq("User2 Post")
        end
      end

      it "can query all posts across users" do
        temporary do
          reinit_example_models

          user1 = User.create!({first_name: "John", last_name: "Doe"})
          user2 = User.create!({first_name: "Jane", last_name: "Smith"})

          Post.create!({title: "User1 Post", user_id: user1.id})
          Post.create!({title: "User2 Post", user_id: user2.id})

          all_posts = Post.query.to_a
          all_posts.size.should eq(2)
          all_posts.map(&.title).should contain("User1 Post")
          all_posts.map(&.title).should contain("User2 Post")
        end
      end
    end

    describe "SQL generation" do
      it "generates correct SQL for posts query" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})

          expected_sql = "SELECT * FROM \"posts\" WHERE (user_id = #{user.id})"

          user.posts.to_sql.should eq(expected_sql)
        end
      end
    end
  end

  context "User -> Comment relationship" do
    describe "basic operations" do
      it "can add comments to user" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          comment1 = Comment.create!({content: "First comment", user_id: user.id})
          comment2 = Comment.create!({content: "Second comment", user_id: user.id})

          user.comments.count.should eq(2)
          user.comments.map(&.content).should contain("First comment")
          user.comments.map(&.content).should contain("Second comment")
        end
      end

      it "can build comments" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})

          comment = user.comments.build({content: "Built comment"})

          comment.persisted?.should be_false
          comment.user_id.should eq(user.id)
          comment.content.should eq("Built comment")

          comment.save!
          user.comments.count.should eq(1)
        end
      end

      it "can create comments directly" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})

          comment = user.comments.create!({content: "Created comment"})

          comment.persisted?.should be_true
          comment.user_id.should eq(user.id)
          user.comments.count.should eq(1)
        end
      end
    end
  end

  context "User -> Relationship (self-referential)" do
    describe "self-referential has_many" do
      it "can create relationships between users" do
        temporary do
          reinit_example_models

          user1 = User.create!({first_name: "Alice", last_name: "Johnson"})
          user2 = User.create!({first_name: "Bob", last_name: "Wilson"})
          user3 = User.create!({first_name: "Charlie", last_name: "Brown"})

          rel1 = user1.relationships.build({dependency_id: user2.id})
          rel2 = user1.relationships.build({dependency_id: user3.id})

          rel1.save!
          rel2.save!

          user1.relationships.count.should eq(2)
          user1.relationships.map(&.dependency_id).should contain(user2.id)
          user1.relationships.map(&.dependency_id).should contain(user3.id)
        end
      end

      it "can create relationships directly" do
        temporary do
          reinit_example_models

          user1 = User.create!({first_name: "Alice", last_name: "Johnson"})
          user2 = User.create!({first_name: "Bob", last_name: "Wilson"})

          relationship = user1.relationships.create!({dependency_id: user2.id})

          relationship.persisted?.should be_true
          relationship.master_id.should eq(user1.id)
          relationship.dependency_id.should eq(user2.id)
          user1.relationships.count.should eq(1)
        end
      end

      it "generates correct SQL for self-referential query" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "Alice", last_name: "Johnson"})

          expected_sql = "SELECT * FROM \"relationships\" WHERE (master_id = #{user.id})"

          user.relationships.to_sql.should eq(expected_sql)
        end
      end
    end
  end

  context "Category -> Post relationship" do
    describe "reverse has_many relationship" do
      it "can query posts from category" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          category = Category.create!({name: "Technology"})

          Post.create!({title: "Tech Post 1", user_id: user.id, category_id: category.id})
          Post.create!({title: "Tech Post 2", user_id: user.id, category_id: category.id})

          category.posts.count.should eq(2)
          category.posts.map(&.title).should contain("Tech Post 1")
          category.posts.map(&.title).should contain("Tech Post 2")
        end
      end

      it "can build posts from category" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          category = Category.create!({name: "Technology"})

          post = category.posts.build({title: "Built from category", user_id: user.id})

          post.persisted?.should be_false
          post.category_id.should eq(category.id)
          post.user_id.should eq(user.id)

          post.save!
          category.posts.count.should eq(1)
        end
      end

      it "can create posts from category" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          category = Category.create!({name: "Technology"})

          post = category.posts.create!({title: "Created from category", user_id: user.id})

          post.persisted?.should be_true
          post.category_id.should eq(category.id)
          post.user_id.should eq(user.id)
          category.posts.count.should eq(1)
        end
      end
    end
  end

  context "Edge cases and error handling" do
    describe "validation and error handling" do
      it "handles invalid posts gracefully" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})

          # Try to create post with empty title (which should fail validation)
          post = user.posts.build({title: ""})
          expect_raises(Lustra::Model::InvalidError) do
            post.valid!
          end

          user.posts.count.should eq(0)
        end
      end

      it "handles non-existent user gracefully" do
        temporary do
          reinit_example_models

          non_existent_user_id = 99999

          posts = Post.query.where({user_id: non_existent_user_id})
          posts.count.should eq(0)
          posts.empty?.should be_true
        end
      end

      it "can handle empty collections" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})

          user.posts.count.should eq(0)
          user.posts.first?.should be_nil
          user.posts.any?.should be_false
          user.posts.empty?.should be_true
        end
      end
    end

    describe "foreign key constraints" do
      it "maintains referential integrity" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          post = Post.create!({title: "Test Post", user_id: user.id})

          # Verify the foreign key relationship
          post.user_id.should eq(user.id)

          # Query through the relationship - compare by ID since objects are different instances
          found_post = user.posts.find!({id: post.id})
          found_post.id.should eq(post.id)
          found_post.title.should eq(post.title)
        end
      end
    end
  end

  context "Eager loading with has_many" do
    describe "eager loading" do
      it "can eager load posts" do
        temporary do
          reinit_example_models

          users = [
            User.create!({first_name: "User1", last_name: "One"}),
            User.create!({first_name: "User2", last_name: "Two"}),
            User.create!({first_name: "User3", last_name: "Three"}),
          ]

          # Create posts for users
          Post.create!({title: "User1 Post", user_id: users[0].id})
          Post.create!({title: "User1 Post 2", user_id: users[0].id})
          Post.create!({title: "User2 Post", user_id: users[1].id})

          loaded_users = User.query.with_posts.to_a

          loaded_users.size.should eq(3)

          # Each user should have their posts loaded without additional queries
          user1 = loaded_users.find! { |u| u.first_name == "User1" }
          user1.posts.count.should eq(2)
          user1.posts.map(&.title).should contain("User1 Post")
          user1.posts.map(&.title).should contain("User1 Post 2")

          user2 = loaded_users.find! { |u| u.first_name == "User2" }
          user2.posts.count.should eq(1)
          user2.posts.first!.title.should eq("User2 Post")

          user3 = loaded_users.find! { |u| u.first_name == "User3" }
          user3.posts.count.should eq(0)
        end
      end

      it "can eager load comments" do
        temporary do
          reinit_example_models

          users = [
            User.create!({first_name: "User1", last_name: "One"}),
            User.create!({first_name: "User2", last_name: "Two"}),
          ]

          Comment.create!({content: "User1 Comment", user_id: users[0].id})
          Comment.create!({content: "User1 Comment 2", user_id: users[0].id})
          Comment.create!({content: "User2 Comment", user_id: users[1].id})

          loaded_users = User.query.with_comments.to_a

          loaded_users.size.should eq(2)

          user1 = loaded_users.find! { |u| u.first_name == "User1" }
          user1.comments.count.should eq(2)

          user2 = loaded_users.find! { |u| u.first_name == "User2" }
          user2.comments.count.should eq(1)
        end
      end
    end
  end

  context "Performance and caching" do
    describe "query caching" do
      it "can use cached results" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          Post.create!({title: "Cached Post", user_id: user.id})

          # First query
          posts1 = user.posts.to_a
          posts1.size.should eq(1)

          # Second query should use cache
          posts2 = user.posts.to_a
          posts2.size.should eq(1)
          posts2.first.title.should eq("Cached Post")
        end
      end

      it "can use eager loading with custom block filtering" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "Test", last_name: "User"})

          # Create posts with different published status
          Post.create!({title: "Published Post", user_id: user.id, published: true})
          Post.create!({title: "Draft Post", user_id: user.id, published: false})

          # Load user with only published posts
          loaded_users = User.query.with_posts do |posts_query|
            posts_query.where({published: true})
          end.to_a

          loaded_users.size.should eq(1)
          loaded_user = loaded_users.first

          # Should only have published posts loaded
          loaded_user.posts.count.should eq(1)
          loaded_user.posts.first!.title.should eq("Published Post")
        end
      end
    end
  end
end
