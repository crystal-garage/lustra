require "../../spec_helper"
require "../../data/example_models"

describe "Lustra::Model::Relations::HasOne" do
  context "User -> UserInfo relationship" do
    describe "basic operations" do
      it "starts without user_info" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})

          user.info.should be_nil
        end
      end

      it "deletes user_info" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          UserInfo.create!({registration_number: 101, user_id: user.id})

          user.info.should_not be_nil

          user.info!.update(bio: "Bio updated")
          user.info!.bio.should eq("Bio updated")
        end
      end

      it "deletes user_info" do
        temporary do
          reinit_example_models

          user = User.create!({first_name: "John", last_name: "Doe"})
          UserInfo.create!({bio: "Bio1", registration_number: 101, user_id: user.id})

          user.info.should_not be_nil

          user.info!.delete
          user.info.should be_nil
        end
      end

      it "can eager load user_info" do
        temporary do
          reinit_example_models

          users = [
            User.create!({first_name: "User1", last_name: "One"}),
            User.create!({first_name: "User2", last_name: "Two"}),
          ]

          UserInfo.create!({bio: "Bio1", registration_number: 101, user_id: users[0].id})
          UserInfo.create!({bio: "Bio2", registration_number: 102, user_id: users[1].id})

          loaded_users = User.query.with_info.to_a

          loaded_users.size.should eq(2)

          user1 = loaded_users.find! { |u| u.first_name == "User1" }
          user1.info.should_not be_nil
          user1.info!.bio.should eq("Bio1")

          user2 = loaded_users.find! { |u| u.first_name == "User2" }
          user2.info.should_not be_nil
          user2.info!.bio.should eq("Bio2")
        end
      end
    end
  end
end
