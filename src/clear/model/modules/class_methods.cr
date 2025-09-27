module Clear::Model::ClassMethods
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

      # Return the table name setup for this model.
      # By convention, the class name is by default equals to the pluralized underscored string form of the model name.
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
      #   include Clear::Model
      #
      #   self.table = "another_table_name"
      # end
      # MyModel.query.to_sql # SELECT * FROM "another_table_name"
      # ```
      class_property table : Clear::SQL::Symbolic = self.name.underscore.gsub(/::/, "_").pluralize

      # Define the current schema used in PostgreSQL. The value is `nil` by default, which lead to non-specified
      #   schema during the querying, and usage of "public" by PostgreSQL.
      #
      # This property can be redefined on initialization. Example:
      #
      # ```
      # class MyModel
      #   include Clear::Model
      #
      #   self.schema = "my_schema"
      # end
      # MyModel.query.to_sql # SELECT * FROM "my_schema"."my_models"
      # ```
      class_property schema : Clear::SQL::Symbolic? = nil

      # returns the fully qualified and escaped name for this table.
      # add schema if schema is different from 'public' (default schema)
      #
      # ex: "schema"."table"
      def self.full_table_name
        if s = schema
          {schema, table}.map { |x| Clear::SQL.escape(x.to_s) }.join(".")
        else
          # Default schema
          Clear::SQL.escape(table)
        end
      end

      class_property __pkey__ : String = "id"

      # :doc:
      # {{@type}}::Collection
      #
      # This is the object managing a `SELECT` request.
      # A new collection is created by calling `{{@type}}.query`
      #
      # Collection are mutable and refining the SQL will mutate the collection.
      # You may want to copy the collection by calling `dup`
      #
      # See `Clear::Model::CollectionBase`
      class Collection < Clear::Model::CollectionBase(\{{@type}}); end

      # Return a new empty query `SELECT * FROM [my_model_table]`. Can be refined after that.
      def self.query
        Collection.new.use_connection(connection).from(self.full_table_name)
      end

      # Returns a model using primary key equality
      # Returns `nil` if not found.
      def self.find(x)
        query.where { raw(__pkey__) == x }.first
      end

      # Returns a model using primary key equality.
      # Raises error if the model is not found.
      def self.find!(x)
        find(x) || raise Clear::SQL::RecordNotFoundError.new
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
          actual_count = Clear::SQL
            .select("COUNT(*)")
            .from(association_name)
            .where { raw(counter_info[:foreign_key]) == id }
            .scalar(Int64)

          # Update counter column directly (bypassing callbacks)
          update_counters(id, {counter_info[:counter_column] => actual_count})
        end
      end

      private def self.update_counters(id, counters)
        # Direct SQL update, no callbacks
        set_clause = counters.map { |k, v| "#{k} = #{v}" }.join(", ")
        Clear::SQL.execute("UPDATE #{full_table_name} SET #{set_clause} WHERE #{__pkey__} = #{id}")
      end
    end
  end
end
