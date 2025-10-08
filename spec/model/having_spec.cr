require "../spec_helper"
require "../data/example_models"

module HavingSpec
  describe "execution of HAVING operations" do
    it "filters using having with has_many through relationship" do
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

        # Find users who have more than 2 tags
        results1 = User.query
          .join(:posts)
          .join(:post_tags) { post_tags.post_id == posts.id }
          .join(:tags) { tags.id == post_tags.tag_id }
          .select("users.*, COUNT(distinct tags.id) AS tag_count")
          .group_by("users.id")
          .having { raw("COUNT(distinct tags.id) > 1") }

        results1.to_sql.should eq(
          "SELECT users.*, COUNT(distinct tags.id) AS tag_count FROM \"users\" INNER JOIN \"posts\" ON (\"posts\".\"user_id\" = \"users\".\"id\") INNER JOIN \"post_tags\" ON (\"post_tags\".\"post_id\" = \"posts\".\"id\") INNER JOIN \"tags\" ON (\"tags\".\"id\" = \"post_tags\".\"tag_id\") GROUP BY users.id HAVING COUNT(distinct tags.id) > 1"
        )

        results1.size.should eq(1)
        results1.first!.first_name.should eq("User 1")
      end
    end
  end
end
