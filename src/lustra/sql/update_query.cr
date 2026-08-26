require "db"
require "pg"
require "./sql"

# An update query
#
# Postgres documentation:
#
# ```
# [ WITH [ RECURSIVE ] with_query [, ...] ]
# UPDATE [ ONLY ] table_name [ * ] [ [ AS ] alias ]
#     SET { column_name = { expression | DEFAULT } |
#           ( column_name [, ...] ) = [ ROW ] ( { expression | DEFAULT } [, ...] ) |
#           ( column_name [, ...] ) = ( sub-SELECT )
#         } [, ...]
#     [ FROM from_item [, ...] ]
#     [ WHERE condition | WHERE CURRENT OF cursor_name ]
#     [ RETURNING * | output_expression [ [ AS ] output_name ] [, ...] ]
# ```
class Lustra::SQL::UpdateQuery
  alias Updatable = Lustra::SQL::Any | BigInt | BigFloat | Time
  alias UpdateInstruction = Hash(String, Updatable) | String

  @values : Array(UpdateInstruction) = [] of UpdateInstruction
  @table : Symbolic?

  include Query::CTE
  include Query::Connection
  include Query::Change
  include Query::Where
  include Query::Execute
  include Query::Returning

  def initialize(@table, @wheres = [] of Lustra::Expression::Node)
  end

  # Add assignments from a named tuple.
  #
  # ```
  # Lustra::SQL.update(:users).set(active: true, name: "Jane")
  # ```
  def set(row : NamedTuple)
    h = {} of String => Updatable
    row.each { |k, v| h[k.to_s] = v }
    set(h)
    change!
  end

  # Add assignments from keyword arguments.
  def set(**row)
    set(row)
  end

  # Add a raw SQL `SET` fragment.
  #
  # ```
  # Lustra::SQL.update(:users).set(%("counter" = "counter" + 1))
  # ```
  #
  # This bypasses value conversion and escaping for the fragment itself.
  def set(row : String)
    @values << row
    change!
  end

  # Add assignments from a string-keyed hash.
  def set(row : Hash(String, Updatable))
    @values << Hash(String, Updatable).new.merge(row) # Merge to avoid a bug in crystal
    change!
  end

  # :nodoc:
  protected def print_value(row : Hash(String, Updatable)) : String
    row.join(", ") { |k, v| [Lustra::SQL.escape(k.to_s), Lustra::Expression[v]].join(" = ") }
  end

  # :nodoc:
  protected def print_values : String
    @values.join(", ") do |x|
      case x
      when String
        x
      when Hash(String, Updatable)
        print_value(x)
      when Nil
        "NULL"
      end
    end
  end

  # Render the SQL statement.
  def to_sql
    # raise Lustra::ErrorMessages.query_building_error("Update Query must have a table clause.") if @table.nil?
    table = @table.is_a?(Symbol) ? SQL.escape(@table.to_s) : @table

    append_returning([print_ctes, "UPDATE", table, "SET", print_values, print_wheres]).compact.join(" ")
  end
end
