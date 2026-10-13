require "random/secure"

module Lustra::SQL::Query::Aggregate
  # Use SQL `COUNT` over your query, and return this number as a Int64
  #
  # as count return always a scalar, the usage of `COUNT(*) OVER GROUP BY` can be done by
  # using `pluck` or `select`
  def count(type : X.class = Int64) forall X
    subquery = dup
    # Ordering matters when it selects rows, but not for an ordinary count.
    if @limit.nil? && @offset.nil? && (@distinct_value.nil? || @distinct_value == "")
      subquery.clear_order_bys
    end
    if @columns.empty? && !@group_bys.empty?
      @group_bys.each { |column| subquery.select(column) }
    end

    X.new(Lustra::SQL.select("COUNT(*)").from({query_count: subquery}).use_connection(connection_name).scalar(Int64))
  end

  # Call an custom aggregation function, like MEDIAN or other:
  #
  # ```
  # query.agg("MEDIAN(age)", Int64)
  # ```
  #
  # Note that COUNT, MIN, MAX, SUM and AVG are already conveniently mapped.
  #
  # This return only one row, and should not be used with `group_by` (prefer pluck or fetch)
  # Automatically handles LIMIT/OFFSET by wrapping in a subquery.
  def agg(field, x : X.class) forall X
    # In case of limit, offset, or group by,
    # we need to wrap in a subquery so the aggregation applies to the filtered set
    if aggregate_subquery?
      # SELECT agg_func FROM ( $subquery ) AS subquery
      subquery = dup
      X.cast(Lustra::SQL.select(field).from({subquery: subquery}).use_connection(connection_name).scalar(X))
    else
      dup.clear_before_query_triggers.clear_select.clear_order_bys.select(field).scalar(X)
    end
  end

  private def aggregate_subquery?
    !@offset.nil? || !@limit.nil? || !@group_bys.empty? || !@distinct_value.nil? || !@columns.empty?
  end

  private def aggregate_column(field, x : X.class, &block : String -> String) forall X
    agg(block.call(field.to_s), X)
  end

  private def aggregate_column(field : SQL::Column, x : X.class, &block : String -> String) forall X
    if @distinct_value == ""
      raise QueryBuildingError.new("Source expressions cannot be aggregated with plain DISTINCT because projection can change its result rows. Pass a selected result column or alias as a string instead.")
    end

    if aggregate_subquery?
      column_alias = "__lustra_aggregate_#{Random::Secure.hex(16)}"
      subquery = dup
      subquery.select(print_wildcard) if @columns.empty?
      subquery.select(SQL::Column.new(field.value, column_alias))
      subquery.agg(block.call(column_alias), X)
    else
      agg(block.call(SQL::Column.new(field.value).to_sql), X)
    end
  end

  # SUM through a field and return a Float64
  # Pass `SQL::Column` to evaluate an expression in the source query's scope.
  # With plain DISTINCT, pass a selected result column or alias as a string instead.
  # The field argument is treated as a raw SQL expression; do not pass untrusted input.
  def sum(field) : Float64
    aggregate_column(field, Union(Int64 | PG::Numeric?)) { |column| "SUM(#{column})" }.try(&.to_f) || 0.0
  end

  # SUM through a field and return the requested PostgreSQL result type.
  # Pass `SQL::Column` to evaluate an expression in the source query's scope.
  # With plain DISTINCT, pass a selected result column or alias as a string instead.
  # The field argument is treated as a raw SQL expression; do not pass untrusted input.
  def sum(field, x : X.class) : X forall X
    aggregate_column(field, x) { |column| "COALESCE(SUM(#{column}), 0)" }
  end

  {% for x in %w[min max avg] %}
    # SQL aggregation function {{ x.upcase }}:
    # Pass `SQL::Column` to evaluate an expression in the source query's scope.
    # With plain DISTINCT, pass a selected result column or alias as a string instead.
    #
    # ```
    # query.{{ x.id }}("field", Int64)
    # ```
    def {{ x.id }}(field, x : X.class) forall X
      aggregate_column(field, X) { |column| "{{ x.id.upcase }}(#{column})" }
    end
  {% end %}

  # Check if any records exist matching the query conditions.
  # Returns `true` if at least one record exists, `false` otherwise.
  #
  # ```
  # User.query.where { active == true }.exists? # => true/false
  # ```
  def exists? : Bool
    return false if @limit == 0

    # Use a simple EXISTS subquery for optimal performance
    Lustra::SQL.select("1").from({subquery: dup.limit(1)}).use_connection(connection_name).first != nil
  end
end
