require "../../spec_helper"
require "../../data/example_models"

module BelongsToSpec
  describe("belongs_to relation (not nilable)") do
    it "access" do
      temporary do
        reinit_example_models

        user = User.create!(first_name: "name")
        post = Post.create!(user: user, title: "title")

        post.user.id.should eq(user.id)
        user.posts.count.should eq(1)
      end
    end

    it "throw error if not found" do
      temporary do
        reinit_example_models

        expect_raises(Exception) do
          Post.create!(user_id: nil) # Bad id
        end
      end
    end

    it "saves model before saving itself if associated model is not persisted" do
      temporary do
        reinit_example_models

        user = User.new({first_name: "name"})
        post = Post.new({user: user, title: "title"})

        post.save!
        post.persisted?.should be_true
        user.persisted?.should be_true
      end
    end

    it "fails to save if the associated model is incorrect" do
      temporary do
        reinit_example_models

        user = User.new
        post = Post.new({user: user, title: "title"})

        post.save.should be_false
        post.errors.size.should eq(1)
        post.errors[0].reason.should eq("first_name: must be present")

        # error correction
        user.first_name = "name"
        post.save.should be_true
      end
    end

    it "avoid n+1 queries" do
      temporary do
        reinit_example_models

        users = {
          User.create!(first_name: "name"),
          User.create!(first_name: "name"),
        }

        5.times do |x|
          Post.create!(user: users.sample, title: "title #{x}")
        end

        post_call = 0
        user_call = 0

        post_query = Post.query.before_query { post_call += 1 }
        post_query.with_user { user_call += 1 }

        post_query.each do |post|
          post_call.should eq(1)
          user_call.should eq(1)

          post.user
        end
      end
    end

    it "touches parent model updated_at when touch: true" do
      temporary do
        reinit_example_models

        user = User.create!(first_name: "name")
        original_updated_at = user.updated_at

        # Sleep a bit to ensure timestamp difference
        sleep 10.milliseconds

        # Create a post with touch: true (default updated_at)
        post = PostWithTouch.create!(user: user, title: "test post")

        # Reload user to get updated timestamp
        user = User.find!(user.id)
        user.updated_at.should_not eq(original_updated_at)
      end
    end

    it "touches specific column when specified" do
      temporary do
        reinit_example_models

        user = User.create!(first_name: "name")
        original_last_comment_at = user.last_comment_at

        # Sleep a bit to ensure timestamp difference
        sleep 10.milliseconds

        comment = Comment.create!(user: user, content: "test comment")

        # Reload user to get updated timestamp
        user = User.find!(user.id)
        user.last_comment_at.should_not eq(original_last_comment_at)
      end
    end

    it "touches parent when child model is updated" do
      temporary do
        reinit_example_models

        user = User.create!(first_name: "name")
        comment = Comment.create!(user: user, content: "test comment")

        # Get the timestamp after creation
        user = User.find!(user.id)
        original_last_comment_at = user.last_comment_at

        # Sleep a bit to ensure timestamp difference
        sleep 10.milliseconds

        # Update the comment
        comment.content = "updated content"
        comment.save!

        # Reload user to get updated timestamp
        user = User.find!(user.id)
        user.last_comment_at.should_not eq(original_last_comment_at)
      end
    end

    it "touches parent updated_at when child model with touch: true is updated" do
      temporary do
        reinit_example_models

        user = User.create!(first_name: "name")
        post = PostWithTouch.create!(user: user, title: "test post")

        # Get the timestamp after creation
        user = User.find!(user.id)
        original_updated_at = user.updated_at

        # Sleep a bit to ensure timestamp difference
        sleep 10.milliseconds

        # Update the post
        post.title = "updated title"
        post.save!

        # Reload user to get updated timestamp
        user = User.find!(user.id)
        user.updated_at.should_not eq(original_updated_at)
      end
    end
  end
end
