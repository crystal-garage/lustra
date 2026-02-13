module Lustra::Model::Introspection
  # Lightweight snapshot of a table column used by `schema_description`.
  struct SchemaColumnInfo
    getter name, data_type, nullable, default_value, collation, description

    def initialize(@name : String, @data_type : String, @nullable : Bool, @default_value : String?, @collation : String?, @description : String?)
    end
  end

  # Summary of a database index used by `schema_description`.
  struct SchemaIndexInfo
    getter name, definition, unique, primary

    def initialize(@name : String, @definition : String, @unique : Bool, @primary : Bool)
    end

    def flags
      bits = [] of String
      bits << "primary" if primary
      bits << "unique" if unique
      bits
    end
  end

  # Full table snapshot combining columns and indexes.
  struct SchemaDescription
    getter schema, table, columns, indexes

    def initialize(@schema : String, @table : String, @columns : Array(SchemaColumnInfo), @indexes : Array(SchemaIndexInfo))
    end
  end

  macro included # When included into Model
    macro included # When included into final Model
      # Return the table description without printing.
      def self.schema_description : SchemaDescription
        __schema_description__
      end

      private def self.__schema_description__
        schema_name = (schema || "public").to_s
        table_name = table.to_s

        SchemaDescription.new(
          schema_name,
          table_name,
          __load_schema_columns__(schema_name, table_name),
          __load_schema_indexes__(schema_name, table_name)
        )
      end

      private def self.__load_schema_columns__(schema_name : String, table_name : String)
        cols = [] of SchemaColumnInfo

        query = Lustra::SQL
          .select({
            column_name:    "a.attname",
            data_type:      "pg_catalog.format_type(a.atttypid, a.atttypmod)",
            nullable:       "NOT a.attnotnull",
            column_default: "pg_get_expr(ad.adbin, ad.adrelid)",
            collation:      "coll.collname",
            description:    "pgd.description",
          })
          .from("pg_catalog.pg_attribute a")
          .join("pg_catalog.pg_class c", condition: "c.oid = a.attrelid")
          .join("pg_catalog.pg_namespace n", condition: "n.oid = c.relnamespace")
          .left_join("pg_catalog.pg_attrdef ad", condition: "ad.adrelid = a.attrelid AND ad.adnum = a.attnum")
          .left_join("pg_catalog.pg_description pgd", condition: "pgd.objoid = a.attrelid AND pgd.objsubid = a.attnum")
          .left_join("pg_catalog.pg_collation coll", condition: "coll.oid = a.attcollation AND a.attcollation <> (SELECT oid FROM pg_catalog.pg_collation WHERE collname = 'default' AND collnamespace = (SELECT oid FROM pg_catalog.pg_namespace WHERE nspname = 'pg_catalog'))")
          .where do
            (n.nspname == schema_name) &
              (c.relname == table_name) &
              raw("a.attnum > 0") &
              raw("NOT a.attisdropped")
          end
          .order_by("a.attnum")
          .use_connection(connection)

        query.fetch(fetch_all: true) do |row|
          nullable = row["nullable"]?.try(&.as(Bool)) || false

          cols << SchemaColumnInfo.new(
            row["column_name"].to_s,
            row["data_type"].to_s,
            nullable,
            row["column_default"]?.try(&.to_s),
            row["collation"]?.try(&.to_s),
            row["description"]?.try(&.to_s)
          )
        end

        cols
      end

      private def self.__load_schema_indexes__(schema_name : String, table_name : String)
        indexes = [] of SchemaIndexInfo

        query = Lustra::SQL
          .select({
            index_name: "i.relname",
            definition: "pg_get_indexdef(ix.indexrelid)",
            is_unique:  "ix.indisunique",
            is_primary: "ix.indisprimary",
          })
          .from("pg_catalog.pg_index ix")
          .join("pg_catalog.pg_class t", condition: "t.oid = ix.indrelid")
          .join("pg_catalog.pg_namespace n", condition: "n.oid = t.relnamespace")
          .join("pg_catalog.pg_class i", condition: "i.oid = ix.indexrelid")
          .where do
            (n.nspname == schema_name) &
              (t.relname == table_name)
          end
          .order_by("i.relname")
          .use_connection(connection)

        query.fetch(fetch_all: true) do |row|
          indexes << SchemaIndexInfo.new(
            row["index_name"].to_s,
            row["definition"].to_s,
            row["is_unique"].as(Bool),
            row["is_primary"].as(Bool)
          )
        end

        indexes
      end
    end
  end
end
