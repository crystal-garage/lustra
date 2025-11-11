module Lustra::Migration::GeometricHelpers
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
end
