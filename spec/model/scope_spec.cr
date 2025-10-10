require "../spec_helper"

module ScopeSpec
  class ScopeModel
    include Lustra::Model

    self.table = "scope_models"

    column value : String?

    # Scope with no parameters
    scope("no_value") { where { value == nil } }

    # Scope with one typed parameter
    scope("with_value") { |x| where { value == x } }

    # Scope with splat parameter
    scope("with_values") { |*x| where { value.in?(x) } }
  end

  class DefaultScopeModel
    include Lustra::Model

    self.table = "default_scope_models"

    primary_key

    column value : Int32?
    column deleted_at : Time?

    # Default scope to filter out deleted records
    default_scope { where { deleted_at == nil } }

    scope("valued") { where { value != nil } }
  end

  class ScopeSpecMigration621253
    include Lustra::Migration

    def change(dir)
      create_table "scope_models" do |t|
        t.column "value", "integer", index: true, null: true
      end
    end
  end

  class DefaultScopeSpecMigration621254
    include Lustra::Migration

    def change(dir)
      create_table "default_scope_models" do |t|
        t.column "value", "integer", null: true
        t.column "deleted_at", "timestamp", null: true
      end
    end
  end

  def self.reinit
    reinit_migration_manager
    ScopeSpecMigration621253.new.apply
  end

  def self.reinit_default_scope
    reinit_migration_manager
    DefaultScopeSpecMigration621254.new.apply
  end

  describe "Lustra::Model::HasScope" do
    it "access to scope with different arguments " do
      temporary do
        reinit

        ScopeModel.create!({value: 1})
        ScopeModel.create!({value: 2})
        ScopeModel.create!({value: 3})

        ScopeModel.create! # Without value

        ScopeModel.no_value.to_sql.should eq("SELECT * FROM \"scope_models\" WHERE (\"value\" IS NULL)")
        ScopeModel.no_value.count.should eq 1
        ScopeModel.with_value(1).to_sql.should eq("SELECT * FROM \"scope_models\" WHERE (\"value\" = 1)")
        ScopeModel.with_value(1).count.should eq 1
        ScopeModel.with_values(1, 2, 3).where { id < 10 }.to_sql.should eq("SELECT * FROM \"scope_models\" WHERE \"value\" IN (1, 2, 3) AND (\"id\" < 10)")
        ScopeModel.with_values(1, 2, 3).count.should eq 3
      end
    end

    context "default_scope" do
      it "applies default scope automatically to all queries" do
        temporary do
          reinit_default_scope

          # Create records with and without deleted_at
          active1 = DefaultScopeModel.create!({value: 1})
          active2 = DefaultScopeModel.create!({value: 2})
          deleted = DefaultScopeModel.create!({value: 3, deleted_at: Time.utc})

          # Default scope should filter out deleted records
          DefaultScopeModel.query.count.should eq(2)
          DefaultScopeModel.query.to_a.map(&.value).should eq([1, 2])
        end
      end

      it "applies default scope to find methods" do
        temporary do
          reinit_default_scope

          active = DefaultScopeModel.create!({value: 1})
          deleted = DefaultScopeModel.create!({value: 2, deleted_at: Time.utc})

          # find should respect default scope
          DefaultScopeModel.find(active.id).should_not be_nil
          DefaultScopeModel.find(deleted.id).should be_nil
        end
      end

      it "can be bypassed with query.unscoped" do
        temporary do
          reinit_default_scope

          active = DefaultScopeModel.create!({value: 1})
          deleted = DefaultScopeModel.create!({value: 2, deleted_at: Time.utc})

          # query.unscoped should return all records
          DefaultScopeModel.query.unscoped.count.should eq(2)
          DefaultScopeModel.query.unscoped.to_a.map(&.value).should eq([1, 2])
        end
      end

      it "works with additional scopes" do
        temporary do
          reinit_default_scope

          DefaultScopeModel.create!({value: 1})
          DefaultScopeModel.create!({value: 2})
          DefaultScopeModel.create!({value: nil})
          DefaultScopeModel.create!({value: 3, deleted_at: Time.utc})

          # default_scope + valued scope
          DefaultScopeModel.valued.count.should eq(2)
          DefaultScopeModel.valued.to_a.map(&.value).should eq([1, 2])
        end
      end

      it "works with where clauses" do
        temporary do
          reinit_default_scope

          DefaultScopeModel.create!({value: 1})
          DefaultScopeModel.create!({value: 2})
          DefaultScopeModel.create!({value: 1, deleted_at: Time.utc})

          # default_scope + where
          result = DefaultScopeModel.query.where(value: 1).to_a
          result.size.should eq(1)
          result.first.value.should eq(1)
          result.first.deleted_at.should be_nil
        end
      end

      it "generates correct SQL with default scope" do
        temporary do
          reinit_default_scope

          sql = DefaultScopeModel.query.to_sql
          sql.should contain("WHERE")
          sql.should contain("deleted_at")
          sql.should contain("IS NULL")
        end
      end
    end
  end
end
