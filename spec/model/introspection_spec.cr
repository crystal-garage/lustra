require "../spec_helper"

module IntrospectionSpec
  class Admin
    include Lustra::Model

    self.table = "admins"
  end

  describe "Model.describe" do
    it "returns schema details for table columns and indexes" do
      temporary do
        Lustra::SQL.execute <<-SQL
          CREATE TABLE admins (
            id BIGSERIAL PRIMARY KEY,
            provider TEXT NOT NULL,
            uid TEXT NOT NULL,
            email TEXT NOT NULL,
            raw_json JSONB,
            created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL
          );
        SQL

        Lustra::SQL.execute "COMMENT ON COLUMN admins.email IS 'Primary email address';"
        Lustra::SQL.execute "CREATE UNIQUE INDEX admins_provider_uid ON admins (provider, uid);"
        Lustra::SQL.execute "CREATE INDEX admins_created_at ON admins (created_at);"

        info = Admin.schema_description

        info.schema.should eq("public")
        info.table.should eq("admins")

        email = info.columns.find(&.name.==("email")).not_nil!
        email.data_type.should eq("text")
        email.nullable.should be_false
        email.description.should eq("Primary email address")

        id_col = info.columns.find(&.name.==("id")).not_nil!
        id_col.default_value.should_not be_nil
        id_col.default_value.not_nil!.should contain("nextval")

        idx_names = info.indexes.map(&.name)
        idx_names.should contain("admins_pkey")
        idx_names.should contain("admins_provider_uid")
        idx_names.should contain("admins_created_at")

        pk = info.indexes.find(&.primary).not_nil!
        pk.unique.should be_true

        provider_uid = info.indexes.find(&.name.==("admins_provider_uid")).not_nil!
        provider_uid.unique.should be_true
        provider_uid.primary.should be_false
      end
    end
  end
end
