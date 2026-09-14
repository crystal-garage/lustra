require "../spec_helper"

module ConflictSkippedSpec
  class Account
    include Lustra::Model

    self.table = "conflict_skipped_accounts"

    primary_key
    column email : String
    column name : String

    property create_callbacks = 0
    property save_callbacks = 0
    after(:create) { |model| model.as(Account).create_callbacks += 1 }
    after(:save) { |model| model.as(Account).save_callbacks += 1 }
  end

  def self.with_account(&)
    temporary do
      Lustra::SQL.execute <<-SQL
        CREATE TABLE conflict_skipped_accounts (
          id bigserial PRIMARY KEY,
          email text NOT NULL UNIQUE,
          name text NOT NULL
        )
        SQL
      existing = Account.create!(email: "same@example.com", name: "Original")
      yield existing
    end
  end

  describe "Conflict-skipped model saves" do
    it "returns false when DO NOTHING skips the insert" do
      with_account do
        skipped = Account.new({email: "same@example.com", name: "Skipped"})
        saved = skipped.save(->(query : Lustra::SQL::InsertQuery) { query.on_conflict.do_nothing })

        Account.query.count.should eq(1)
        Account.query.first!.name.should eq("Original")
        saved.should be_false
      end
    end

    it "keeps a skipped model unpersisted with its pending attributes" do
      with_account do
        skipped = Account.new({email: "same@example.com", name: "Initial"})
        skipped.name = "Skipped"
        skipped.save(->(query : Lustra::SQL::InsertQuery) { query.on_conflict.do_nothing })

        skipped.persisted?.should be_false
        skipped.name.should eq("Skipped")
        skipped.name_column.changed?.should be_true
      end
    end

    it "does not run successful-create callbacks for a skipped insert" do
      with_account do
        skipped = Account.new({email: "same@example.com", name: "Skipped"})
        skipped.save(->(query : Lustra::SQL::InsertQuery) { query.on_conflict.do_nothing })

        skipped.create_callbacks.should eq(0)
        skipped.save_callbacks.should eq(0)
      end
    end

    it "raises from save! when DO NOTHING skips the insert" do
      with_account do
        skipped = Account.new({email: "same@example.com", name: "Skipped"})
        expect_raises(Lustra::Model::InvalidError) do
          skipped.save!(&.on_conflict.do_nothing)
        end
        skipped.persisted?.should be_false
      end
    end

    it "also preserves skipped state through save_with_associations" do
      with_account do
        skipped = Account.new({email: "same@example.com", name: "Initial"})
        skipped.name = "Skipped"
        skipped.save_with_associations(->(query : Lustra::SQL::InsertQuery) { query.on_conflict.do_nothing }).should be_false

        skipped.persisted?.should be_false
        skipped.name_column.changed?.should be_true
        skipped.create_callbacks.should eq(0)
        skipped.save_callbacks.should eq(0)
      end
    end

    it "persists a nonconflicting insert with DO NOTHING" do
      with_account do
        inserted = Account.new({email: "new@example.com", name: "Inserted"})
        inserted.save(->(query : Lustra::SQL::InsertQuery) { query.on_conflict.do_nothing }).should be_true

        inserted.persisted?.should be_true
        inserted.name_column.changed?.should be_false
        inserted.create_callbacks.should eq(1)
        Account.find!(inserted.id).name.should eq("Inserted")
      end
    end

    it "uses the returned row when the conflict updates an existing account" do
      with_account do |existing|
        updated = Account.new({email: "same@example.com", name: "Updated"})
        updated.save(->(query : Lustra::SQL::InsertQuery) do
          query.on_conflict("(email)").do_update(&.set("name = excluded.name"))
        end).should be_true

        updated.persisted?.should be_true
        updated.id.should eq(existing.id)
        updated.name.should eq("Updated")
        updated.name_column.changed?.should be_false
        Account.find!(existing.id).name.should eq("Updated")
      end
    end
  end
end
