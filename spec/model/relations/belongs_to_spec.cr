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

  describe("belongs_to relation (nilable)") do
    it "access" do
      temporary do
        reinit_example_models

        post = PostWithOptionalUser.create!(title: "title")

        post.user.should be_nil
      end
    end
  end

  describe("polymorphic belongs_to relation") do
    it "assigns an employee parent" do
      temporary do
        reinit_example_models

        employee = Employee.create!(name: "employee")
        picture = Picture.new({name: "picture"})
        picture.imageable = employee

        picture.imageable_id.should eq(employee.id)
        picture.imageable_type.should eq("Employee")
        picture.imageable.should eq(employee)
      end
    end

    it "assigns a product parent" do
      temporary do
        reinit_example_models

        product = Product.create!(name: "product")
        picture = Picture.new({name: "picture"})
        picture.imageable = product

        picture.imageable_id.should eq(product.id)
        picture.imageable_type.should eq("Product")
        picture.imageable.should eq(product)
      end
    end

    it "creates a record with a polymorphic parent" do
      temporary do
        reinit_example_models

        employee = Employee.create!(name: "employee")
        picture = Picture.create!(name: "employee picture", imageable: employee)

        persisted_picture = Picture.find!(picture.id)
        persisted_picture.imageable_id.should eq(employee.id)
        persisted_picture.imageable_type.should eq("Employee")
        persisted_picture.imageable.as(Employee).id.should eq(employee.id)
      end
    end

    it "creates a record with a concrete polymorphic alias" do
      temporary do
        reinit_example_models

        employee = Employee.create!(name: "employee")
        picture = Picture.create!(name: "employee picture", employee: employee)

        persisted_picture = Picture.find!(picture.id)
        persisted_picture.imageable_id.should eq(employee.id)
        persisted_picture.imageable_type.should eq("Employee")
        persisted_picture.employee.id.should eq(employee.id)
      end
    end

    it "resolves the parent using the stored type" do
      temporary do
        reinit_example_models

        employee = Employee.create!(name: "employee")
        product = Product.create!(name: "product")

        employee.id.should eq(product.id)

        employee_picture = Picture.create!(
          name: "employee picture",
          imageable_id: employee.id,
          imageable_type: "Employee"
        )
        product_picture = Picture.create!(
          name: "product picture",
          imageable_id: product.id,
          imageable_type: "Product"
        )

        employee_picture.imageable.as(Employee).id.should eq(employee.id)
        product_picture.imageable.as(Product).id.should eq(product.id)
      end
    end

    it "resolves concrete type aliases" do
      temporary do
        reinit_example_models

        employee = Employee.create!(name: "employee")
        product = Product.create!(name: "product")

        employee.id.should eq(product.id)

        employee_picture = Picture.create!(
          name: "employee picture",
          imageable_id: employee.id,
          imageable_type: "Employee"
        )
        product_picture = Picture.create!(
          name: "product picture",
          imageable_id: product.id,
          imageable_type: "Product"
        )

        employee_picture.employee.id.should eq(employee.id)

        expect_raises(Lustra::SQL::RecordNotFoundError) do
          product_picture.employee
        end
      end
    end

    it "eager loads parents by stored type" do
      temporary do
        reinit_example_models

        employee = Employee.create!(name: "employee")
        product = Product.create!(name: "product")

        employee.id.should eq(product.id)

        Picture.create!(
          name: "employee picture",
          imageable_id: employee.id,
          imageable_type: "Employee"
        )
        Picture.create!(
          name: "product picture",
          imageable_id: product.id,
          imageable_type: "Product"
        )

        pictures = Picture.query.with_imageable.order_by(:name)

        pictures[0].imageable.as(Employee).id.should eq(employee.id)
        pictures[1].imageable.as(Product).id.should eq(product.id)
      end
    end

    it "eager loads concrete type aliases" do
      temporary do
        reinit_example_models

        employee = Employee.create!(name: "employee")
        product = Product.create!(name: "product")

        employee.id.should eq(product.id)

        Picture.create!(
          name: "employee picture",
          imageable_id: employee.id,
          imageable_type: "Employee"
        )
        Picture.create!(
          name: "product picture",
          imageable_id: product.id,
          imageable_type: "Product"
        )

        pictures = Picture.query.with_employee.order_by(:name)

        pictures[0].employee.id.should eq(employee.id)

        expect_raises(Lustra::SQL::RecordNotFoundError) do
          pictures[1].employee
        end
      end
    end

    it "raises a clear error for an unknown stored type" do
      temporary do
        reinit_example_models

        picture = Picture.create!(
          name: "picture",
          imageable_id: 1,
          imageable_type: "Unknown"
        )

        expect_raises(Exception, /Unknown polymorphic type 'Unknown' for Picture#imageable/) do
          picture.imageable
        end
      end
    end

    it "supports namespaced target model types" do
      temporary do
        reinit_example_models

        employee = PolymorphicSpec::Employee.create!(name: "employee")
        product = PolymorphicSpec::Product.create!(name: "product")

        employee.id.should eq(product.id)

        picture = PolymorphicSpec::Picture.new({name: "employee picture"})
        picture.imageable = employee

        picture.imageable_id.should eq(employee.id)
        picture.imageable_type.should eq("PolymorphicSpec::Employee")
        picture.save!

        product_picture = PolymorphicSpec::Picture.create!(
          name: "product picture",
          imageable_id: product.id,
          imageable_type: "PolymorphicSpec::Product"
        )

        employee.pictures.first!.imageable.as(PolymorphicSpec::Employee).id.should eq(employee.id)
        product_picture.imageable.as(PolymorphicSpec::Product).id.should eq(product.id)

        pictures = PolymorphicSpec::Picture.query.with_imageable.order_by(:name)

        pictures[0].imageable.as(PolymorphicSpec::Employee).id.should eq(employee.id)
        pictures[1].imageable.as(PolymorphicSpec::Product).id.should eq(product.id)
      end
    end
  end
end
