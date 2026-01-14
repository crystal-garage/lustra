module Lustra::Migration
  class AddColumn < Operation
    # ALTER TABLE {TABLENAME}
    # ADD {COLUMNNAME} {TYPE} {NULL|NOT NULL}
    # CONSTRAINT {CONSTRAINT_NAME} DEFAULT {DEFAULT_VALUE}
    # WITH VALUES

    @table : String
    @column : String
    @datatype : String

    @constraint : String?
    @default : String?
    @nullable : Bool

    @with_values : Bool
    @comment : String?

    def initialize(
      @table,
      @column,
      datatype,
      @nullable = false,
      @constraint = nil,
      @default = nil,
      @with_values = false,
      @comment = nil,
    )
      @datatype = Lustra::Migration::Helper.datatype(datatype.to_s)
    end

    def up : Array(String)
      constraint = @constraint
      default = @default
      with_values = @with_values

      statements = [[
        "ALTER TABLE", @table, "ADD", @column, @datatype, @nullable ? "NULL" : "NOT NULL",
        constraint ? "CONSTRAINT #{constraint}" : nil, default ? "DEFAULT #{default}" : nil,
        with_values ? "WITH VALUES" : nil,
      ].compact.join(" ")]

      if comment = @comment
        esc = comment.gsub("'", "''")
        statements << "COMMENT ON COLUMN #{@table}.#{@column} IS '#{esc}'"
      end

      statements
    end

    def down : Array(String)
      ["ALTER TABLE #{@table} DROP #{@column}"]
    end
  end

  class RemoveColumn < Operation
    @table : String
    @column : String
    @datatype : String

    def initialize(@table, @column, datatype)
      @datatype = Lustra::Migration::Helper.datatype(datatype)
    end

    def up : Array(String)
      ["ALTER TABLE #{@table} DROP #{@column}"]
    end

    def down : Array(String)
      ["ALTER TABLE #{@table} ADD #{@column} #{@datatype}"]
    end
  end

  class RenameColumn < Operation
    @table : String
    @old_column_name : String
    @new_column_name : String

    def initialize(@table, @old_column_name, @new_column_name)
    end

    def up : Array(String)
      ["ALTER TABLE #{@table} RENAME COLUMN #{@old_column_name} TO #{@new_column_name};"]
    end

    def down : Array(String)
      ["ALTER TABLE #{@table} RENAME COLUMN #{@new_column_name} TO #{@old_column_name};"]
    end
  end

  class ChangeColumnType < Operation
    @table : String
    @column_name : String
    @new_column_type : String
    @old_column_type : String

    def initialize(
      @table,
      @column_name,
      old_column_type,
      new_column_type,
    )
      @old_column_type = Lustra::Migration::Helper.datatype(old_column_type)
      @new_column_type = Lustra::Migration::Helper.datatype(new_column_type)
    end

    def up : Array(String)
      ["ALTER TABLE #{@table} ALTER COLUMN #{@column_name} SET DATA TYPE #{@new_column_type};"]
    end

    def down : Array(String)
      ["ALTER TABLE #{@table} ALTER COLUMN #{@column_name} SET DATA TYPE #{@old_column_type};"]
    end
  end

  class ChangeColumnNull < Operation
    @table : String
    @column_name : String
    @null : Bool
    @default_value : String?

    def initialize(@table, @column_name, @null, @default_value = nil)
    end

    def up : Array(String)
      statements = [] of String

      # If setting NOT NULL and a default value is provided, update existing NULLs first
      if !@null && @default_value
        statements << "UPDATE #{@table} SET #{@column_name} = #{@default_value} WHERE #{@column_name} IS NULL;"
      end

      if @null
        statements << "ALTER TABLE #{@table} ALTER COLUMN #{@column_name} DROP NOT NULL;"
      else
        statements << "ALTER TABLE #{@table} ALTER COLUMN #{@column_name} SET NOT NULL;"
      end

      statements
    end

    def down : Array(String)
      if @null
        ["ALTER TABLE #{@table} ALTER COLUMN #{@column_name} SET NOT NULL;"]
      else
        ["ALTER TABLE #{@table} ALTER COLUMN #{@column_name} DROP NOT NULL;"]
      end
    end
  end

  class AddIndex < Operation
    @table : String
    @columns : Array(String)
    @index_name : String
    @unique : Bool
    @using : String?

    def initialize(@table, columns, name = nil, @unique = false, @using = nil)
      @columns = columns.is_a?(Array) ? columns.map(&.to_s) : [columns.to_s]
      @index_name = name || safe_index_name("index_#{@table}_on_#{@columns.join("_and_")}")
    end

    def up : Array(String)
      unique_keyword = @unique ? "UNIQUE " : ""
      using_clause = @using ? "USING #{@using}" : ""

      ["CREATE #{unique_keyword}INDEX #{@index_name} ON #{@table} #{using_clause}(#{@columns.join(", ")});".gsub(/\s+/, " ").strip]
    end

    def down : Array(String)
      ["DROP INDEX #{@index_name};"]
    end

    private def safe_index_name(str)
      str.underscore.gsub(/[^a-zA-Z0-9_]+/, "_")
    end
  end

  # Set or change a column's comment
  class ChangeColumnComment < Operation
    @table : String
    @column_name : String
    @from : String?
    @to : String?

    def initialize(@table, @column_name, @from : String?, @to : String?)
    end

    private def esc(txt : String)
      txt.gsub("'", "''")
    end

    def up : Array(String)
      if to = @to
        ["COMMENT ON COLUMN #{@table}.#{@column_name} IS '#{esc(to)}';"]
      else
        ["COMMENT ON COLUMN #{@table}.#{@column_name} IS NULL;"]
      end
    end

    def down : Array(String)
      if from = @from
        ["COMMENT ON COLUMN #{@table}.#{@column_name} IS '#{esc(from)}';"]
      else
        ["COMMENT ON COLUMN #{@table}.#{@column_name} IS NULL;"]
      end
    end
  end

  # Set or change a column's default value (reversible when using from/to)
  class ChangeColumnDefault < Operation
    @table : String
    @column_name : String
    @from : String?
    @to : String?

    def initialize(@table, @column_name, @from : String?, @to : String?)
    end

    private def val(x : String?)
      x.nil? ? nil : x
    end

    def up : Array(String)
      if to = @to
        ["ALTER TABLE #{@table} ALTER COLUMN #{@column_name} SET DEFAULT #{to};"]
      else
        ["ALTER TABLE #{@table} ALTER COLUMN #{@column_name} DROP DEFAULT;"]
      end
    end

    def down : Array(String)
      if from = @from
        ["ALTER TABLE #{@table} ALTER COLUMN #{@column_name} SET DEFAULT #{from};"]
      else
        ["ALTER TABLE #{@table} ALTER COLUMN #{@column_name} DROP DEFAULT;"]
      end
    end
  end
end

module Lustra::Migration::Helper
  # Add a column to a specific table
  def add_column(
    table,
    column,
    datatype,
    nullable = false,
    constraint = nil,
    default = nil,
    with_values = false,
    comment : String? = nil,
  )
    add_operation(
      Lustra::Migration::AddColumn.new(
        table,
        column,
        datatype,
        nullable,
        constraint,
        default,
        with_values,
        comment
      )
    )
  end

  def drop_column(table, column, type)
    add_operation(
      Lustra::Migration::RemoveColumn.new(table, column, type)
    )
  end

  def rename_column(table, from, to)
    add_operation(
      Lustra::Migration::RenameColumn.new(table, from, to)
    )
  end

  def change_column_type(table, column, from, to)
    add_operation(
      Lustra::Migration::ChangeColumnType.new(table, column, from, to)
    )
  end

  def change_column_null(table, column, null : Bool, default = nil)
    add_operation(
      Lustra::Migration::ChangeColumnNull.new(table, column, null, default)
    )
  end

  def add_index(table, columns, name = nil, unique = false, using = nil)
    add_operation(
      Lustra::Migration::AddIndex.new(table, columns, name, unique, using)
    )
  end

  # Change a column's comment.
  # - Pass a String to set comment, or nil to remove it (not auto-reversible).
  # - Pass a NamedTuple {from: "old", to: "new"} to make the change reversible.
  def change_column_comment(table, column, to : String?)
    add_operation(
      Lustra::Migration::ChangeColumnComment.new(table, column, nil, to)
    )
  end

  def change_column_comment(table, column, changes : NamedTuple(from: String?, to: String?))
    add_operation(
      Lustra::Migration::ChangeColumnComment.new(table, column, changes[:from], changes[:to])
    )
  end

  # Change a column's default value.
  # - Pass a SQL literal as String to set the default (e.g. "'guest'", "1", "now()") or nil to drop it.
  # - Pass a NamedTuple {from: <old>, to: <new>} to make the change reversible.
  def change_column_default(table, column, to : String?)
    add_operation(
      Lustra::Migration::ChangeColumnDefault.new(table, column, nil, to)
    )
  end

  def change_column_default(table, column, changes : NamedTuple(from: String?, to: String?))
    add_operation(
      Lustra::Migration::ChangeColumnDefault.new(table, column, changes[:from], changes[:to])
    )
  end
end
