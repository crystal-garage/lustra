require "../spec_helper"
require "../data/example_models"

module CTESpec
  describe "Common Table Expressions (CTE)" do
    it "finds users with multiple tags using CTE" do
      temporary do
        reinit_example_models

        user1 = User.create!(first_name: "User 1")
        user2 = User.create!(first_name: "User 2")

        user1_post1 = user1.posts.create!(title: "User 1 Post 1", published: true)
        user1_post2 = user1.posts.create!(title: "User 1 Post 2", published: true)
        user2_post1 = user2.posts.create!(title: "User 2 Post 1", published: true)
        user2_post2 = user2.posts.create!(title: "User 2 Post 2", published: true)

        tag1 = Tag.create!(name: "Tag 1")
        tag2 = Tag.create!(name: "Tag 2")

        # User1 has multiple tags (through multiple posts)
        user1_post1.tags << tag1
        user1_post2.tags << tag1
        user1_post2.tags << tag2

        # User2 has only one tag (through multiple posts)
        user2_post1.tags << tag1
        user2_post2.tags << tag1

        # Create the CTE query
        cte_query = User.query
          .join(:posts) { posts.user_id == users.id }
          .join(:post_tags) { post_tags.post_id == posts.id }
          .join(:tags) { tags.id == post_tags.tag_id }
          .select("users.*, COUNT(DISTINCT tags.id) as tag_count")
          .group_by("users.id")

        # Query users with multiple tags using the CTE - returns User instances
        # We use clear_from to remove the automatic "users" table that User.query adds,
        # allowing us to SELECT directly from our CTE instead of the original table
        users_with_multiple_tags = User.query
          .with_cte("tagged_users", cte_query)
          .clear_from
          .from(:tagged_users)
          .where { tag_count > 1 }

        users_with_multiple_tags.size.should eq(1)
        users_with_multiple_tags.first!.first_name.should eq("User 1")
      end
    end
  end
end
