module Lustra::SQL::Query::Aggregate
  # Use SQL `COUNT` over your query, and return this number as a Int64
  #
  # as count return always a scalar, the usage of `COUNT(*) OVER GROUP BY` can be done by
  # using `pluck` or `select`
  def count(type : X.class = Int64) forall X
    subquery = self
    if @columns.empty? && !@group_bys.empty?
      subquery = dup
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
    if @offset || @limit || @group_bys
      # SELECT agg_func FROM ( $subquery ) AS subquery
      subquery = dup
      source = field.to_s.match(/[A-Za-z_]\w*(?=\.[A-Za-z_]\w*)/).try(&.[0]) || "subquery"
      X.cast(Lustra::SQL.select(field).from("(#{subquery.to_sql}) #{Lustra::SQL.escape(source)}").use_connection(connection_name).scalar(X))
    else
      dup.clear_select.clear_order_bys.select(field).scalar(X)
    end
  end

  # SUM through a field and return a Float64
  # The field argument is treated as a raw SQL expression; do not pass untrusted input.
  def sum(field) : Float64
    agg("SUM(#{field})", Union(Int64 | PG::Numeric?)).try(&.to_f) || 0.0
  end

  # SUM through a field and return the requested PostgreSQL result type.
  # The field argument is treated as a raw SQL expression; do not pass untrusted input.
  def sum(field, x : X.class) : X forall X
    agg("COALESCE(SUM(#{field}), 0)", x)
  end

  {% for x in %w[min max avg] %}
    # SQL aggregation function {{ x.upcase }}:
    #
    # ```
    # query.{{ x.id }}("field", Int64)
    # ```
    def {{ x.id }}(field, x : X.class) forall X
      agg("{{ x.id.upcase }}(#{field})", X)
    end
  {% end %}

  # Check if any records exist matching the query conditions.
  # Returns `true` if at least one record exists, `false` otherwise.
  #
  # ```
  # User.query.where { active == true }.exists? # => true/false
  # ```
  def exists? : Bool
    # Use a simple EXISTS subquery for optimal performance
    Lustra::SQL.select("1").from({subquery: dup.limit(1)}).use_connection(connection_name).first != nil
  end
end
