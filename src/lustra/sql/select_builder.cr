require "./query/**"

module Lustra::SQL::SelectBuilder
  include Query::Select
  include Query::From
  include Query::Join

  include Query::Where
  include Query::Having

  include Query::OrderBy
  include Query::GroupBy
  include Query::OffsetLimit
  include Query::Aggregate

  include Query::CTE
  include Query::Window
  include Query::Lock

  include Query::Execute
  include Query::Fetch
  include Query::Pluck

  include Query::Connection
  include Query::Change
  include Query::BeforeQuery
  include Query::WithPagination

  def initialize(@distinct_value = nil,
                 @cte = {} of String => Lustra::SQL::SelectBuilder | String,
                 @columns = [] of SQL::Column,
                 @froms = [] of SQL::From,
                 @joins = [] of SQL::Join,
                 @wheres = [] of Lustra::Expression::Node,
                 @havings = [] of Lustra::Expression::Node,
                 @windows = [] of {String, String},
                 @group_bys = [] of Symbolic,
                 @order_bys = [] of Lustra::SQL::Query::OrderBy::Record,
                 @limit = nil,
                 @offset = nil,
                 @lock = nil,
                 @before_query_triggers = [] of -> Nil)
  end

  # Duplicate the query
  def dup : self
    self.class.new(
      distinct_value: @distinct_value,
      cte: @cte.dup,
      columns: @columns.dup,
      froms: @froms.dup,
      joins: @joins.dup,
      wheres: @wheres.dup,
      havings: @havings.dup,
      windows: @windows.dup,
      group_bys: @group_bys.dup,
      order_bys: @order_bys.dup,
      limit: @limit,
      offset: @offset,
      lock: @lock,
      before_query_triggers: @before_query_triggers
    ).use_connection(connection_name)
  end

  def to_sql : String
    [print_ctes,
     print_select,
     print_froms,
     print_joins,
     print_wheres,
     print_windows,
     print_group_bys,
     print_havings,
     print_order_bys,
     print_limit_offsets,
     print_lock].compact.reject(&.empty?).join(" ")
  end

  # Construct a delete query from this select query.
  # It uses only the `from` and the `where` clause fo the current select request.
  # Can be useful in some case, but
  #   use at your own risk !
  def to_delete
    raise QueryBuildingError.new("Cannot build a delete query " +
                                 "from a select with multiple or none `from` clauses") unless @froms.size == 1

    v = @froms[0].value

    raise QueryBuildingError.new("Cannot delete from a select with sub-select as `from` clause") if v.is_a?(SelectBuilder)

    DeleteQuery.new(v.dup, @wheres.dup)
  end

  def to_update
    raise QueryBuildingError.new("Cannot build a update query " +
                                 "from a select with multiple or none `from` clauses") unless @froms.size == 1
    v = @froms[0].value

    raise QueryBuildingError.new("Cannot delete from a select with sub-select as `from` clause") if v.is_a?(SelectBuilder)

    UpdateQuery.new(table: v.dup, wheres: @wheres.dup)
  end

  # Build SQL `where NOT` condition using the Expression engine.
  # This is equivalent to wrapping the condition in `NOT(...)`.
  #
  # ```
  # query.where.not { id == 1 }        # WHERE NOT (id = 1)
  # query.where.not { active == true } # WHERE NOT (active = true)
  # ```
  def not(&)
    where(Lustra::Expression.new.not(Lustra::Expression.ensure_node!(with Lustra::Expression.new yield)))
  end

  # Build SQL `where NOT` condition using a NamedTuple.
  # This will negate each condition in the tuple.
  #
  # ```
  # query.where.not({active: true})  # WHERE NOT (active = true)
  # query.where.not({id: [1, 2, 3]}) # WHERE NOT (id IN (1,2,3))
  # ```
  def not(**tuple)
    not(conditions: tuple)
  end

  # Build SQL `where NOT` condition using a NamedTuple or Hash.
  def not(conditions : NamedTuple | Hash(String, Lustra::SQL::Any))
    conditions.each do |k, v|
      k = Lustra::Expression::Node::Variable.new(k.to_s)

      negated_node =
        case v
        when Array
          Lustra::Expression::Node::InArray.new(k, v.map { |it| Lustra::Expression[it] })
        when SelectBuilder
          Lustra::Expression::Node::InSelect.new(k, v)
        when Range
          Lustra::Expression::Node::InRange.new(k,
            Lustra::Expression[v.begin]..Lustra::Expression[v.end],
            v.exclusive?)
        else
          Lustra::Expression::Node::DoubleOperator.new(k,
            Lustra::Expression::Node::Literal.new(v),
            (v.nil? ? "IS" : "=")
          )
        end

      where(Lustra::Expression.new.not(negated_node))
    end

    self
  end

  # Build SQL `where NOT` condition using a template string.
  #
  # ```
  # query.where.not("id = :id", id: 1) # WHERE NOT (id = 1)
  # ```
  def not(template : String, **tuple)
    where(Lustra::Expression.new.not(Lustra::Expression::Node::Raw.new(Lustra::SQL.raw(template, **tuple))))
  end

  # Build SQL `where NOT` condition using a template string with positional parameters.
  #
  # ```
  # query.where.not("id = ?", 1) # WHERE NOT (id = 1)
  # ```
  def not(template : String, *args)
    where(Lustra::Expression.new.not(Lustra::Expression::Node::Raw.new(Lustra::SQL.raw(template, *args))))
  end

  # Build custom SQL `where NOT` condition.
  # Beware of SQL injections!
  #
  # ```
  # query.where.not("id = 1") # WHERE NOT (id = 1)
  # ```
  def not(template : String)
    where(Lustra::Expression.new.not(Lustra::Expression::Node::Raw.new(template)))
  end
end
