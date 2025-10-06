require "../spec_helper"

module SeedSpec
  class SeedModel
    include Lustra::Model

    self.table = "seed_models"

    primary_key

    column value : String
  end

  class SeedModelMigration96842
    include Lustra::Migration

    def change(dir)
      create_table "seed_models" do |t|
        t.column "value", "string", index: true, null: false
      end
    end
  end

  def self.reinit
    reinit_migration_manager
    SeedModelMigration96842.new.apply
  end

  Lustra.seed do
    SeedModel.create!({value: "val_a"})
  end

  Lustra.seed do
    SeedModel.create!({value: "val_b"})
  end

  describe "Lustra::Model::HasScope" do
    it "access to scope with different arguments " do
      temporary do
        reinit

        Lustra.apply_seeds

        SeedModel.query.count.should eq 2
        SeedModel.query.last!.value.should eq "val_b"
      end
    end
  end
end
