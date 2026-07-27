module Lustra::Model::ClassMethods
  alias OnDuplicate = Symbol | Lustra::Expression::UnsafeSql

  macro included # When included into Model
    macro included # When included into final Model
      # :nodoc:
      # Registry for counter caches pointing to this model
      COUNTER_CACHES = {} of String => NamedTuple(counter_column: String, foreign_key: String)

      # Register a counter cache for this model using model class
      def self.register_counter_cache(association_model : Class, counter_column : String, foreign_key : String)
        association_name = association_model.table.to_s

        COUNTER_CACHES[association_name] = {
          counter_column: counter_column,
          foreign_key: foreign_key,
        }
      end

      macro inherited #Polymorphism
        macro finished
          __generate_relations__
          __generate_columns__
          __register_factory__
        end
      end

      macro finished
        __generate_relations__
        __generate_columns__
        __register_factory__
      end

      # Return the table name configured for this model.
      # By convention, the class name defaults to the pluralized, underscored
      # string form of the model name.
      # Example:
      #
      # ```
      # MyModel => "my_models"
      # Person => "people"
      # Project::Info => "project_infos"
      # ```
      #
      # The property can be updated at initialization to a custom table name:
      #
      # ```
      # class MyModel
      #   include Lustra::Model
      #
      #   self.table = "another_table_name"
      # end
      # MyModel.query.to_sql # SELECT * FROM "another_table_name"
      # ```
      class_property table : Lustra::SQL::Symbolic = self.name.underscore.gsub(/::/, "_").pluralize

      # Define the current PostgreSQL schema. The value is `nil` by default,
      # which means no schema is specified during querying, so PostgreSQL uses
      # "public".
      #
      # This property can be redefined on initialization. Example:
      #
      # ```
      # class MyModel
      #   include Lustra::Model
      #
      #   self.schema = "my_schema"
      # end
      # MyModel.query.to_sql # SELECT * FROM "my_schema"."my_models"
      # ```
      class_property schema : Lustra::SQL::Symbolic? = nil

      # Return the fully qualified and escaped name for this table.
      # Add schema if schema is different from 'public' (default schema).
      #
      # ex: "schema"."table"
      def self.full_table_name
        if s = schema
          {schema, table}.map { |x| Lustra::SQL.escape(x.to_s) }.join(".")
        else
          # Default schema
          Lustra::SQL.escape(table)
        end
      end

      class_property __pkey__ : String = "id"

      # :doc:
      # {{ @type }}::Collection
      #
      # This is the object managing a `SELECT` request.
      # A new collection is created by calling `{{ @type }}.query`.
      #
      # Collections are mutable, and refining the SQL mutates the collection.
      # You may want to copy the collection by calling `dup`
      #
      # See `Lustra::Model::CollectionBase`
      class Collection < Lustra::Model::CollectionBase(\{{@type}}); end

      # Return a new query `SELECT * FROM [my_model_table]`. It can be refined after that.
      # Automatically applies default_scope if defined.
      def self.query
        q = Collection.new.use_connection(connection).from(self.full_table_name)
        # Apply default scope if the method exists
        q.responds_to?(:__apply_default_scope__) ? q.__apply_default_scope__ : q
      end

      # :nodoc:
      # Internal method used by Collection#unscoped to get a clean query.
      def self.__unscoped_query__
        Collection.new.use_connection(connection).from(self.full_table_name)
      end

      # Return an empty, chainable collection (Rails-like `.none`).
      # Useful for conditional branches where no records should be returned
      # while keeping query chaining intact.
      #
      # ```
      # User.none.where { active == true }.count # => 0
      # ```
      def self.none
        query.none
      end

      # Returns a model using primary key equality
      # Returns `nil` if not found.
      def self.find(x)
        query.find(x)
      end

      # Find multiple models by an array of primary keys.
      # Returns an array of models (may be empty if none found).
      #
      # ```
      # users = User.find([1, 2, 3])
      # users.size # => 0..3 depending on how many were found
      # ```
      def self.find(ids : Array)
        query.find(ids)
      end

      # Returns a model using primary key equality.
      # Raises error if the model is not found.
      def self.find!(x)
        query.find!(x)
      end

      # Find multiple models by an array of primary keys.
      # Raises error if ANY of the IDs are not found.
      #
      # ```
      # users = User.find!([1, 2, 3]) # Raises if any ID is not found
      # ```
      def self.find!(ids : Array)
        query.find!(ids)
      end

      # Find a model by column values. Returns `nil` if not found.
      # This is an alias for `query.find(**tuple)` with better naming.
      #
      # ```
      # user = User.find_by(email: "test@example.com")
      # user = User.find_by(first_name: "John", last_name: "Doe")
      # ```
      def self.find_by(**tuple)
        query.find_by(**tuple)
      end

      # :ditto:
      def self.find_by(tuple : NamedTuple)
        query.find_by(tuple)
      end

      # Find a model by column values. Raises error if not found.
      # This is an alias for `query.find!(**tuple)` with better naming.
      #
      # ```
      # user = User.find_by!(email: "test@example.com")
      # ```
      def self.find_by!(**tuple)
        query.find_by!(**tuple)
      end

      # :ditto:
      def self.find_by!(tuple : NamedTuple)
        query.find_by!(tuple)
      end

      # Build a new empty model and fill the columns using the NamedTuple in argument.
      #
      # Returns the new model
      def self.build(**tuple : **T) forall T
        \\{% if T.size > 0 %}
          self.new(tuple)
        \\{% else %}
          self.new
        \\{% end %}
      end

      # :ditto:
      def self.build(**tuple)
        build(**tuple) { }
      end

      # :ditto:
      def self.build(**tuple, &block)
        r = build(**tuple)

        yield(r)

        r
      end

      # :ditto:
      def self.build(x : NamedTuple) : self
        build(**x) { }
      end

      # :ditto:
      def self.build(x : NamedTuple, &block : self -> Nil) : self
        build(**x, &block)
      end

      # Build and new model and save it. Returns the model.
      #
      # The model may not be saved due to validation failure;
      # check the returned model `errors?` and `persisted?` flags.
      def self.create(**tuple, &block : self -> Nil) : self
        r = build(**tuple) do |mdl|
          yield(mdl)
        end

        r.save

        r
      end

      # :ditto:
      def self.create(**tuple) : self
        create(**tuple) { }
      end

      # :ditto:
      def self.create(x : NamedTuple) : self
        create(**x) { }
      end

      # :ditto:
      def self.create(x : NamedTuple, &block : self -> Nil) : self
        create(**x, &block)
      end

      # Build and new model and save it. Returns the model.
      #
      # Returns the newly inserted model
      # Raises an exception if validation failed during the saving process.
      def self.create!(**tuple, &block : self -> Nil) : self
        r = build(**tuple) do |mdl|
          yield(mdl)
        end

        r.save!

        r
      end

      # :ditto:
      def self.create!(**tuple) : self
        create!(**tuple) { }
      end

      # :ditto:
      def self.create!(x : NamedTuple) : self
        create!(**x) { }
      end

      # :ditto:
      def self.create!(x : NamedTuple, &block : self -> Nil) : self
        create!(**x, &block)
      end

      # Insert one row with one SQL statement.
      #
      # This bypasses model instantiation, validations, and callbacks.
      def self.insert(row : NamedTuple, returning = __pkey__, unique_by = nil, record_timestamps = nil) : Hash(String, Lustra::SQL::Any)?
        insert_all([row], returning: returning, unique_by: unique_by, record_timestamps: record_timestamps).first?
      end

      # Insert many rows with one SQL statement.
      #
      # This bypasses model instantiation, validations, and callbacks.
      #
      # By default, duplicate rows are skipped by any unique index PostgreSQL
      # reports during `ON CONFLICT DO NOTHING`.
      def self.insert_all(rows : Array(NamedTuple), returning = __pkey__, unique_by = nil, record_timestamps = nil) : Array(Hash(String, Lustra::SQL::Any))
        return [] of Hash(String, Lustra::SQL::Any) if rows.empty?
        raise ArgumentError.new("insert_all does not support record_timestamps yet.") if record_timestamps

        insert_rows = rows.map { |row| __insert_all_row_to_h(row) }
        __ensure_insert_all_rows_have_same_keys(insert_rows)

        query = Lustra::SQL.insert_into(self.full_table_name)
          .values(insert_rows)
          .on_conflict(__insert_all_conflict_target(unique_by))
          .do_nothing

        if returning_sql = __insert_all_returning(returning)
          result = [] of Hash(String, Lustra::SQL::Any)
          query.returning(returning_sql).fetch(@@connection) do |hash|
            result << hash.dup
          end
          result
        else
          query.execute(@@connection)
          [] of Hash(String, Lustra::SQL::Any)
        end
      end

      # Insert or update a single row by conflict target.
      #
      # This bypasses validations and callbacks, like Rails' `upsert`.
      # Use `save` with an `on_conflict` block when lifecycle hooks are needed.
      #
      # Pass `Lustra::SQL.unsafe` to `on_duplicate` for a custom `SET` clause.
      # Custom conflict updates cannot be combined with `update_only`.
      # Set `returning` to `false` to skip `RETURNING *` and model construction.
      def self.upsert(row : NamedTuple, unique_by : Symbol | String = __pkey__, on_duplicate : Lustra::Model::ClassMethods::OnDuplicate = :update, update_only : Enumerable(Lustra::SQL::Symbolic)? = nil, returning : Bool = true) : self?
        upsert_all([row], unique_by: unique_by, on_duplicate: on_duplicate, update_only: update_only, returning: returning).first?
      end

      # Insert or update a single row by array conflict target.
      def self.upsert(row : NamedTuple, unique_by : Array(Lustra::SQL::Symbolic), on_duplicate : Lustra::Model::ClassMethods::OnDuplicate = :update, update_only : Enumerable(Lustra::SQL::Symbolic)? = nil, returning : Bool = true) : self?
        upsert_all([row], unique_by: unique_by, on_duplicate: on_duplicate, update_only: update_only, returning: returning).first?
      end

      # Insert or update a single row by composite conflict target.
      #
      # ```
      # Model.upsert({tenant_id: 1, slug: "intro", title: "Intro"}, unique_by: {:tenant_id, :slug})
      # ```
      def self.upsert(row : NamedTuple, unique_by : Tuple, on_duplicate : Lustra::Model::ClassMethods::OnDuplicate = :update, update_only : Enumerable(Lustra::SQL::Symbolic)? = nil, returning : Bool = true) : self?
        upsert_all([row], unique_by: unique_by, on_duplicate: on_duplicate, update_only: update_only, returning: returning).first?
      end

      # Insert or update many rows by conflict target.
      #
      # Returns the rows saved by PostgreSQL's `RETURNING *`, or an empty array
      # when `returning` is `false`.
      def self.upsert_all(rows : Array(NamedTuple), unique_by : Symbol | String = __pkey__, on_duplicate : Lustra::Model::ClassMethods::OnDuplicate = :update, update_only : Enumerable(Lustra::SQL::Symbolic)? = nil, returning : Bool = true) : Array(self)
        return [] of self if rows.empty?

        upsert_all(rows, unique_by: {unique_by}, on_duplicate: on_duplicate, update_only: update_only, returning: returning)
      end

      # Insert or update many rows by array conflict target.
      #
      # Returns the rows saved by PostgreSQL's `RETURNING *`.
      def self.upsert_all(rows : Array(NamedTuple), unique_by : Array(Lustra::SQL::Symbolic), on_duplicate : Lustra::Model::ClassMethods::OnDuplicate = :update, update_only : Enumerable(Lustra::SQL::Symbolic)? = nil, returning : Bool = true) : Array(self)
        return [] of self if rows.empty?

        __upsert_all(rows, unique_by, on_duplicate, update_only, returning)
      end

      # Insert or update many rows by composite conflict target.
      #
      # Returns the rows saved by PostgreSQL's `RETURNING *`.
      def self.upsert_all(rows : Array(NamedTuple), unique_by : Tuple, on_duplicate : Lustra::Model::ClassMethods::OnDuplicate = :update, update_only : Enumerable(Lustra::SQL::Symbolic)? = nil, returning : Bool = true) : Array(self)
        return [] of self if rows.empty?

        __upsert_all(rows, unique_by, on_duplicate, update_only, returning)
      end

      private def self.__upsert_all(rows : Array(NamedTuple), unique_by, on_duplicate : Lustra::Model::ClassMethods::OnDuplicate, update_only, returning : Bool) : Array(self)
        conflict_columns = __upsert_column_names(unique_by)
        update_columns = __upsert_update_columns(rows.first.keys, conflict_columns, update_only)

        query = Lustra::SQL.insert_into(self.full_table_name, rows.map { |row| build(row).to_h })
          .on_conflict(__upsert_conflict_target(conflict_columns))

        case on_duplicate
        when :skip
          query.do_nothing
        when :update
          if update_columns.empty?
            query.do_nothing
          else
            query.do_update do |update|
              update.set(update_columns.join(", ") do |column|
                escaped = Lustra::SQL.escape(column)
                "#{escaped} = excluded.#{escaped}"
              end)
            end
          end
        when Lustra::Expression::UnsafeSql
          raise ArgumentError.new("on_duplicate and update_only are mutually exclusive.") if update_only

          query.do_update do |update|
            update.set(on_duplicate.to_sql)
          end
        else
          raise ArgumentError.new("Unsupported on_duplicate value: #{on_duplicate}. Use :update, :skip, or Lustra::SQL.unsafe.")
        end

        unless returning
          query.execute(@@connection)
          return [] of self
        end

        saved = [] of self
        query.returning("*").fetch(@@connection) do |hash|
          saved << Lustra::Model::Factory.build(self.name, hash, persisted: true,
            fetch_columns: false, cache: nil).as(self)
        end
        saved
      end

      private def self.__upsert_column_names(unique_by : Array(Lustra::SQL::Symbolic)) : Array(String)
        unique_by.map(&.to_s)
      end

      private def self.__upsert_column_names(unique_by : Tuple) : Array(String)
        unique_by.to_a.map(&.to_s)
      end

      private def self.__upsert_conflict_target(columns : Array(String)) : String
        "(" + columns.join(", ") { |column| Lustra::SQL.escape(column) } + ")"
      end

      private def self.__upsert_update_columns(row_columns, conflict_columns : Array(String), update_only) : Array(String)
        selected_columns =
          if update_only
            update_only.map(&.to_s).to_a
          else
            row_columns.to_a.map(&.to_s)
          end

        selected_columns.reject { |column| conflict_columns.includes?(column) }
      end

      private def self.__insert_all_row_to_h(row : NamedTuple) : Hash(String, Lustra::SQL::InsertQuery::Inserable)
        out = {} of String => Lustra::SQL::InsertQuery::Inserable
        row.each do |key, value|
          out[key.to_s] = value.as(Lustra::SQL::InsertQuery::Inserable)
        end
        out
      end

      private def self.__ensure_insert_all_rows_have_same_keys(rows)
        keys = rows.first.keys
        rows.each do |row|
          unless row.keys == keys
            raise ArgumentError.new("All rows passed to insert_all must have the same keys.")
          end
        end
      end

      private def self.__insert_all_conflict_target(unique_by : Nil)
        true
      end

      private def self.__insert_all_conflict_target(unique_by : Symbol | String)
        __upsert_conflict_target([unique_by.to_s])
      end

      private def self.__insert_all_conflict_target(unique_by : Array(Lustra::SQL::Symbolic))
        __upsert_conflict_target(unique_by.map(&.to_s))
      end

      private def self.__insert_all_conflict_target(unique_by : Tuple)
        __upsert_conflict_target(unique_by.to_a.map(&.to_s))
      end

      private def self.__insert_all_returning(returning : Nil)
        Lustra::SQL.escape(__pkey__)
      end

      private def self.__insert_all_returning(returning : Bool)
        returning ? Lustra::SQL.escape(__pkey__) : nil
      end

      private def self.__insert_all_returning(returning : Symbol)
        Lustra::SQL.escape(returning)
      end

      private def self.__insert_all_returning(returning : String)
        returning
      end

      private def self.__insert_all_returning(returning : Array(Lustra::SQL::Symbolic))
        returning.join(", ") { |column| Lustra::SQL.escape(column) }
      end

      private def self.__insert_all_returning(returning : Tuple)
        returning.to_a.join(", ") { |column| column.is_a?(Symbol) ? Lustra::SQL.escape(column) : column.to_s }
      end

      def self.columns
        @@columns
      end

      # Reset counter cache columns to their correct values.
      # This is useful when counter caches become out of sync due to direct SQL operations.
      #
      # Example:
      # ```
      # User.reset_counters(user.id, Post)
      # User.reset_counters(user.id, Post, Comment)
      # ```
      def self.reset_counters(id, *counter_models)
        counter_models.each do |counter_model|
          association_name = counter_model.table.to_s

          counter_info = COUNTER_CACHES[association_name]?

          unless counter_info
            raise "Counter cache for #{counter_model.name} not found for #{self.name}"
          end

          # Count actual records using direct SQL query
          actual_count = Lustra::SQL
            .select("COUNT(*)")
            .from(association_name)
            .where { raw(counter_info[:foreign_key]) == id }
            .use_connection(@@connection)
            .scalar(Int64)

          # Update counter column directly (bypassing callbacks)
          update_counters(id, {counter_info[:counter_column] => actual_count})
        end
      end

      private def self.update_counters(id, counters)
        # Direct SQL update, no callbacks
        updates = {} of String => Lustra::SQL::UpdateQuery::Updatable
        counters.each { |column, value| updates[column.to_s] = value }
        Lustra::SQL.update(full_table_name)
          .set(updates)
          .where { raw(__pkey__) == id }
          .execute(@@connection)
      end

      # Reset counter cache columns
      #
      # Example:
      # ```
      # user = User.find(1)
      # user.reset_counters(Post)
      # user.reset_counters(Post, Comment)
      # ```
      def reset_counters(*counter_models)
        self.class.reset_counters(self.__pkey__, *counter_models)
        # Reload the instance to get the updated counter values
        reload
      end
    end
  end
end
