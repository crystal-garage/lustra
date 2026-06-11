# Reflection of columns exposed by PostgreSQL's information_schema.
# information_schema.columns is a PostgreSQL view, but mapping it as a read-only
# model keeps the regular query and association APIs available.
class Lustra::Reflection::Column
  include Lustra::Model

  self.schema = "information_schema"
  self.table = "columns"
  self.read_only = true

  column table_catalog : String
  column table_schema : String
  column table_name : String
  column column_name : String, primary: true

  belongs_to table : Lustra::Reflection::Table?, foreign_key: "table_name", foreign_key_type: String
end
