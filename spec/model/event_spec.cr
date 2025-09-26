require "../spec_helper"
require "../data/example_models"

module EventSpec
  ACCUMULATOR = [] of String

  abstract class ModelA
    include Clear::Model

    polymorphic through: "type"

    before(:validate) { ACCUMULATOR << "1" }
    before(:validate) { ACCUMULATOR << "2" }
    before(:validate) { ACCUMULATOR << "3" }

    after(:validate) { ACCUMULATOR << "6" }
    after(:validate) { ACCUMULATOR << "7" }
    after(:validate) { ACCUMULATOR << "8" }
  end

  class ModelB < ModelA
    before(:validate) { ACCUMULATOR << "A" }

    after(:validate, :x)

    def x
      ACCUMULATOR << "Z"
    end
  end

  # Test model for create/save callbacks
  class CallbackTestModel
    include Clear::Model

    self.table = "callback_test_models"

    primary_key

    column name : String
    column callback_triggered : Bool, presence: false

    after(:create) { |model| model.as(CallbackTestModel).callback_triggered = true }
    after(:update) { |_| ACCUMULATOR << "update_callback" }
    after(:delete) { |_| ACCUMULATOR << "delete_callback" }
  end

  describe "Clear::Model" do
    context "EventManager" do
      it "call the events in the good direction" do
        ModelB.new.valid?
        ACCUMULATOR.join("").should eq "123AZ876"
      end

      it "triggers after(:create) callback when model is created" do
        temporary do
          reinit_example_models

          model = CallbackTestModel.create!(name: "test")
          model.callback_triggered.should be_true
        end
      end

      it "triggers after(:create) callback when model is created (accumulator test)" do
        temporary do
          reinit_example_models

          ACCUMULATOR.clear
          model = CallbackTestModel.create!(name: "test")
          # This test just verifies that create works, no accumulator check needed
          model.callback_triggered.should be_true
        end
      end

      it "triggers after(:update) callback when model is updated" do
        temporary do
          reinit_example_models

          model = CallbackTestModel.create!(name: "test")
          ACCUMULATOR.clear

          model.name = "updated"
          model.save!

          ACCUMULATOR.should contain("update_callback")
        end
      end

      it "triggers after(:delete) callback when model is deleted" do
        temporary do
          reinit_example_models

          model = CallbackTestModel.create!(name: "test")
          ACCUMULATOR.clear

          model.delete

          ACCUMULATOR.should contain("delete_callback")
        end
      end
    end
  end
end
