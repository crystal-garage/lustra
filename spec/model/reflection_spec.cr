require "../spec_helper"

module ReflectionSpec
  describe "Lustra::Reflection::Table" do
    context "querying" do
      it "list the tables" do
        temporary do
          first_table = Lustra::Reflection::Table.query.first!
          first_table.columns.first!
        end
      end

      it "will fail to update the view" do
        temporary do
          first_table = Lustra::Reflection::Table.query.first!

          expect_raises Lustra::Model::ReadOnlyError do
            first_table.save!
          end

          first_table.columns.first!.save.should be_false

          expect_raises Lustra::Model::ReadOnlyError do
            first_table.columns.first!.save!
          end
        end
      end
    end
  end
end
