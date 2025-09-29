module Lustra::Migration
  abstract class Operation
    include Lustra::ErrorMessages

    property migration : Lustra::Migration? = nil

    abstract def up : Array(String)
    abstract def down : Array(String)

    def irreversible!(operation_name : String? = nil)
      operation_name ||= self.class.name
      migration_name = migration ? migration.class.name : nil
      raise IrreversibleMigration.new(migration_irreversible(migration_name, operation_name))
    end
  end
end

require "./*"
