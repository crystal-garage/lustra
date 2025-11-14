# Feature WHERE clause building.
# each call to where method stack where clause.
# Theses clauses are then combined together using the `AND` operator.
# Therefore, `query.where("a").where("b")` will return `a AND b`
#
module Lustra::SQL::Query::Where
  macro included
    # Return the list of where clause; each where clause are transformed into
    # Lustra::Expression::Node
    getter wheres : Array(Lustra::Expression::Node)
  end

  # Build SQL `where` condition using a Lustra::Expression::Node
  #
  # ```
  # query.where(Lustra::Expression::Node::InArray.new("id", ['1', '2', '3', '4']))
  # # Note: in this example, InArray node use unsafe strings
  # ```
  #
  # If useful for moving a where clause from a request to another one:
  #
  # ```
  # query1.where { a == b } # WHERE a = b
  # ```
  #
  # ```
  # query2.where(query1.wheres[0]) # WHERE a = b
  # ```
  def where(node : Lustra::Expression::Node)
    @wheres << node

    change!
  end

  # Build SQL `where` condition using the Expression engine.
  #
  # ```
  # query.where { id == 1 }
  # ```
  def where(&)
    where(Lustra::Expression.ensure_node!(with Lustra::Expression.new yield))
  end

  def where(**tuple)
    where(conditions: tuple)
  end

  # Build SQL `where` condition using a NamedTuple.
  # this will use:
  # - the `=` operator if compared with a literal
  #
  # ```
  # query.where({keyword: "hello"}) # WHERE keyword = 'hello'
  # ```
  #
  # - the `IN` operator if compared with an array:
  #
  # ```
  # query.where({x: [1, 2]}) # WHERE x in (1,2)
  # ```
  #
  # - the `>=` and `<=` | `<` if compared with a range:
  #
  # ```
  # query.where({x: (1..4)})  # WHERE x >= 1 AND x <= 4
  # query.where({x: (1...4)}) # WHERE x >= 1 AND x < 4
  # query.where({x: (1..)})   # WHERE  x >= 1
  # query.where({x: (..10)})  # WHERE  x <= 10
  # query.where({x: (...10)}) # WHERE x < 10
  # ```
  #
  # - You also can put another select query as argument:
  #
  # ```
  # query.where({x: another_select}) # WHERE x IN (SELECT ... )
  # ```
  def where(conditions : NamedTuple | Hash(String, Lustra::SQL::Any))
    conditions.each do |k, v|
      k = Lustra::Expression::Node::Variable.new(k.to_s)

      @wheres <<
        case v
        when Array
          Lustra::Expression::Node::InArray.new(k, v.map { |it| Lustra::Expression[it] })
        when SelectBuilder
          Lustra::Expression::Node::InSelect.new(k, v)
        when Range
          range_begin = v.begin.nil? ? nil : Lustra::Expression[v.begin]
          range_end = v.end.nil? ? nil : Lustra::Expression[v.end]
          Lustra::Expression::Node::InRange.new(k, range_begin..range_end, v.exclusive?)
        else
          Lustra::Expression::Node::DoubleOperator.new(k,
            Lustra::Expression::Node::Literal.new(v),
            (v.nil? ? "IS" : "=")
          )
        end
    end

    change!
  end

  # Build SQL `where` interpolating `:keyword` with the NamedTuple passed in argument.
  #
  # ```
  # where("id = :id OR date >= :start", id: 1, start: 1.day.ago)
  # # WHERE id = 1 AND date >= '201x-xx-xx ...'
  # ```
  def where(template : String, **tuple)
    where(Lustra::Expression::Node::Raw.new(Lustra::SQL.raw(template, **tuple)))
  end

  # Build SQL `where` condition using a template string and
  # interpolating `?` characters with parameters given in a tuple or array.
  #
  # ```
  # where("x = ? OR y = ?", 1, "l'eau") # WHERE x = 1 OR y = 'l''eau'
  # ```
  #
  # Raise error if there's not enough parameters to cover all the `?` placeholders
  def where(template : String, *args)
    where(Lustra::Expression::Node::Raw.new(Lustra::SQL.raw(template, *args)))
  end

  # Build custom SQL `where`
  # beware of SQL injections!
  #
  # ```
  # where("ADD_SOME_DANGEROUS_SQL_HERE") # WHERE ADD_SOME_DANGEROUS_SQL_HERE
  # ```
  def where(template : String)
    @wheres << Lustra::Expression::Node::Raw.new(template)
    change!
  end

  # Clear all the where clauses and return `self`
  def clear_wheres
    @wheres.clear

    change!
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
          range_begin = v.begin.nil? ? nil : Lustra::Expression[v.begin]
          range_end = v.end.nil? ? nil : Lustra::Expression[v.end]
          Lustra::Expression::Node::InRange.new(k, range_begin..range_end, v.exclusive?)
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

  # Build SQL `where OR` condition using the Expression engine.
  #
  # ```
  # query.where { id == 1 }.or { id == 2 } # WHERE (id = 1) OR (id = 2)
  # query.where.or { active == true }      # WHERE active = true
  # ```
  def or(node : Lustra::Expression::Node)
    return where(node) if @wheres.empty?

    # Optimisation: if we have a OR Array as root, we use it and append directly the element.
    if @wheres.size == 1 &&
       (n = @wheres.first) &&
       n.is_a?(Lustra::Expression::Node::NodeArray) &&
       n.link == "OR"
      n.expression << node
    else
      # Concatenate the old clauses in a list of AND conditions
      if @wheres.size == 1
        old_clause = @wheres.first
      else
        old_clause = Lustra::Expression::Node::NodeArray.new(@wheres, "AND")
      end

      @wheres.clear
      @wheres << Lustra::Expression::Node::NodeArray.new([old_clause, node], "OR")
    end

    change!
  end

  # Build SQL `where OR` condition using the Expression engine.
  #
  # ```
  # query.where { id == 1 }.or { id == 2 }
  # ```
  def or(&)
    or(Lustra::Expression.ensure_node!(with Lustra::Expression.new yield))
  end

  # Build SQL `where OR` condition using a NamedTuple.
  #
  # ```
  # query.where { id == 1 }.or(status: "active") # WHERE (id = 1) OR (status = 'active')
  # ```
  def or(**tuple)
    or(conditions: tuple)
  end

  # Build SQL `where OR` condition using a NamedTuple or Hash.
  def or(conditions : NamedTuple | Hash(String, Lustra::SQL::Any))
    # Build a node array for all conditions in the tuple
    nodes = [] of Lustra::Expression::Node

    conditions.each do |k, v|
      k = Lustra::Expression::Node::Variable.new(k.to_s)

      nodes <<
        case v
        when Array
          Lustra::Expression::Node::InArray.new(k, v.map { |it| Lustra::Expression[it] })
        when SelectBuilder
          Lustra::Expression::Node::InSelect.new(k, v)
        when Range
          range_begin = v.begin.nil? ? nil : Lustra::Expression[v.begin]
          range_end = v.end.nil? ? nil : Lustra::Expression[v.end]
          Lustra::Expression::Node::InRange.new(k, range_begin..range_end, v.exclusive?)
        else
          Lustra::Expression::Node::DoubleOperator.new(k,
            Lustra::Expression::Node::Literal.new(v),
            (v.nil? ? "IS" : "=")
          )
        end
    end

    # If multiple conditions in the tuple, combine them with AND
    combined_node =
      if nodes.size == 1
        nodes.first
      else
        Lustra::Expression::Node::NodeArray.new(nodes, "AND")
      end

    or(combined_node)
  end

  # Build SQL `where OR` condition using a template string.
  #
  # ```
  # query.where { id == 1 }.or("status = :status", status: "active")
  # ```
  def or(template : String, **tuple)
    or(Lustra::Expression::Node::Raw.new(Lustra::Expression.raw("(#{template})", **tuple)))
  end

  # Build SQL `where OR` condition using a template string with positional parameters.
  #
  # ```
  # query.where { id == 1 }.or("status = ?", "active")
  # ```
  def or(template : String, *args)
    or(Lustra::Expression::Node::Raw.new(Lustra::Expression.raw("(#{template})", *args)))
  end

  # :nodoc:
  protected def print_wheres
    {"WHERE ", @wheres.join(" AND ", &.resolve)}.join unless @wheres.empty?
  end
end
