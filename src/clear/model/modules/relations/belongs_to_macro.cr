# :nodoc:
module Clear::Model::Relations::BelongsToMacro
  macro generate(
    self_type,
    method_name,
    relation_type,
    nilable,
    foreign_key,
    primary,
    no_cache,
    foreign_key_type,
    touch,
    counter_cache,
  )
    {% foreign_key = foreign_key || method_name.stringify.underscore + "_id" %}

    {%
      relation_type_nilable =
        if nilable
          "#{relation_type} | Nil".id
        else
          relation_type
        end
    %}

    column {{foreign_key.id}} : {{foreign_key_type}}, primary: {{primary}}, presence: {{nilable}}
    getter _cached_{{method_name}} : {{relation_type}}?

    protected def invalidate_caching
      previous_def

      @_cached_{{method_name}} = nil

      self
    end

    # The method {{method_name}} is a `belongs_to` relation to {{relation_type}}
    def {{method_name}} : {{relation_type_nilable}}
      if cached = @_cached_{{method_name}}
        cached
      else
        cache = @cache

        if cache && cache.active? "{{method_name}}"
          {% if nilable %}
            @_cached_{{method_name}} = cache.hit("{{method_name}}",
              self.{{foreign_key.id}}_column.to_sql_value, {{relation_type}}
            ).first?
          {% else %}
            @_cached_{{method_name}} = cache.hit("{{method_name}}",
              self.{{foreign_key.id}}_column.to_sql_value, {{relation_type}}
            ).first? || raise Clear::SQL::RecordNotFoundError.new
          {% end %}
        else
          {% if nilable %}
            @_cached_{{method_name}} = {{relation_type}}.query.where { raw({{relation_type}}.__pkey__) == self.{{foreign_key.id}} }.first
          {% else %}
            @_cached_{{method_name}} = {{relation_type}}.query.where { raw({{relation_type}}.__pkey__) == self.{{foreign_key.id}} }.first!
          {% end %}
        end
      end
    end

    {% if nilable %}
      def {{method_name}}! : {{relation_type}}
        {{method_name}}.not_nil!
      end

      def {{method_name}}=(model : {{relation_type_nilable}})
        if model
          if model.persisted?
            raise "#{model.__pkey_column__.name} must be defined when assigning a belongs_to relation." unless model.__pkey_column__.defined?

            @{{foreign_key.id}}_column.value = model.__pkey__
          end

          @_cached_{{method_name}} = model
        else
          @{{foreign_key.id}}_column.value = nil
        end
      end
    {% else %}
      def {{method_name}}=(model : {{relation_type}})
        if model.persisted?
          raise "#{model.__pkey_column__.name} must be defined when assigning a belongs_to relation." unless model.__pkey_column__.defined?

          @{{foreign_key.id}}_column.value = model.__pkey__
        end

        @_cached_{{method_name}} = model
      end
    {% end %}

    # :nodoc:
    # save the belongs_to model first if needed
    def _bt_save_{{method_name}}
      c = @_cached_{{method_name}}

      return if c.nil?

      if c.persisted?
        @{{foreign_key.id}}_column.value = c.__pkey__
      else
        if c.save
          @{{foreign_key.id}}_column.value = c.__pkey__
        else
          add_error("{{method_name}}", c.print_errors)
        end
      end
    end

    {% if touch %}
      # :nodoc:
      # touch the parent model's timestamp column
      def _bt_touch_{{method_name}}
        {% if nilable %}
          parent = {{method_name}}
          return if parent.nil?
        {% else %}
          parent = {{method_name}}
        {% end %}

        {% if touch == true %}
          parent.touch
        {% else %}
          # Touch a specific column
          parent.{{touch}} = Time.local
          parent.save!
        {% end %}

        # Reload the parent to ensure the timestamp is updated
        parent.reload
      end
    {% end %}

    {% if counter_cache %}
      # :nodoc:
      # Execute atomic counter cache update
      def _bt_update_counter_{{method_name}}(operation : String)
        {% if nilable %}
          parent = {{method_name}}
          return if parent.nil?
        {% else %}
          parent = {{method_name}}
        {% end %}

        {% if counter_cache == true %}
          counter_column_name = "#{self.class.table}_count"
        {% else %}
          counter_column_name = "{{counter_cache}}"
        {% end %}

        Clear::SQL.execute(<<-SQL)
          UPDATE #{parent.class.full_table_name}
              SET #{counter_column_name} = #{counter_column_name} #{operation}
            WHERE #{parent.class.__pkey__} = #{parent.__pkey__}
          SQL
      end

      # :nodoc:
      # increment counter cache on the parent model
      def _bt_increment_counter_{{method_name}}
        _bt_update_counter_{{method_name}}("+ 1")
      end

      # :nodoc:
      # decrement counter cache on the parent model
      def _bt_decrement_counter_{{method_name}}
        _bt_update_counter_{{method_name}}("- 1")
      end
    {% end %}

    __on_init__ do
      {{self_type}}.before(:validate) do |mdl|
        mdl.as(self)._bt_save_{{method_name}}
      end

      {% if touch %}
        {{self_type}}.after(:create) do |mdl|
          mdl.as(self)._bt_touch_{{method_name}}
        end
        {{self_type}}.after(:update) do |mdl|
          mdl.as(self)._bt_touch_{{method_name}}
        end
      {% end %}

      {% if counter_cache %}
        {{self_type}}.after(:create) do |mdl|
          mdl.as(self)._bt_increment_counter_{{method_name}}
        end
        {{self_type}}.after(:delete) do |mdl|
          mdl.as(self)._bt_decrement_counter_{{method_name}}
        end
      {% end %}
    end

    class Collection
      def with_{{method_name}}(fetch_columns = false, &block : {{relation_type}}::Collection ->) : self
        before_query do
          sub_query = self.dup.clear_select.select("#{{{self_type}}.table}.{{foreign_key.id}}")

          cached_qry = {{relation_type}}.query.where { raw("#{{{relation_type}}.table}.#{{{relation_type}}.__pkey__}").in?(sub_query) }

          block.call(cached_qry)

          @cache.active "{{method_name}}"

          cached_qry.each(fetch_columns: fetch_columns) do |mdl|
            @cache.set("{{method_name}}", mdl.__pkey__, [mdl])
          end
        end

        self
      end

      def with_{{method_name}}(fetch_columns = false) : self
        with_{{method_name}}(fetch_columns) { }

        self
      end
    end
  end
end
