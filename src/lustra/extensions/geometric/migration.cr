module Lustra::Migration::GeometricHelpers
  # Create spatial index for geometric columns
  def add_gist_index(table : String, column : String, name : String? = nil)
    index_name = name || "#{table}_#{column}_gist_idx"
    up_sql("CREATE INDEX #{index_name} ON #{table} USING GIST (#{column})")
  end

  # Create spatial index with custom operator class
  def add_gist_index(table : String, column : String, operator_class : String, name : String? = nil)
    index_name = name || "#{table}_#{column}_#{operator_class}_idx"
    up_sql("CREATE INDEX #{index_name} ON #{table} USING GIST (#{column} #{operator_class})")
  end

  # Add exclusion constraint for geometric types
  def add_exclusion_constraint(table : String, column : String, operator : String = "&&", name : String? = nil)
    constraint_name = name || "#{table}_#{column}_exclusion"
    up_sql("ALTER TABLE #{table} ADD CONSTRAINT #{constraint_name} EXCLUDE USING GIST (#{column} WITH #{operator})")
  end

  # Add check constraint for geometric bounds
  def add_geometric_bounds_check(table : String, column : String, bounds, name : String? = nil)
    constraint_name = name || "#{table}_#{column}_bounds_check"
    up_sql("ALTER TABLE #{table} ADD CONSTRAINT #{constraint_name} CHECK (#{column} @ '#{bounds}')")
  end

  # Drop geometric constraint
  def drop_geometric_constraint(table : String, constraint_name : String)
    down_sql("ALTER TABLE #{table} DROP CONSTRAINT IF EXISTS #{constraint_name}")
  end

  # Drop spatial index
  def drop_gist_index(name : String)
    down_sql("DROP INDEX IF EXISTS #{name}")
  end
end
