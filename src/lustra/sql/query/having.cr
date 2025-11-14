module Lustra::SQL::Query::Having
  macro included
    getter havings : Array(Lustra::Expression::Node)
  end

  # Build SQL `having` condition using a Lustra::Expression::Node
  #
  # ```
  # query.having(Lustra::Expression::Node::InArray.new("id", ['1', '2', '3', '4']))
  # # Note: in this example, InArray node use unsafe strings
  # ```
  #
  # If useful for moving a having clause from a request to another one:
  #
  # ```
  # query1.having { a == b } # having a = b
  # ```
  #
  # ```
  # query2.having(query1.havings[0]) # HAVING a = b
  # ```
  def having(node : Lustra::Expression::Node)
    @havings << node
    change!
  end

  # Build SQL `having` condition using the Expression engine.
  #
  # ```
  # query.having { id == 1 }
  # ```
  def having(&)
    having(Lustra::Expression.ensure_node!(with Lustra::Expression.new yield))
  end

  def having(**tuple)
    having(conditions: tuple)
  end

  # Build SQL `having` condition using a NamedTuple.
  # this will use:
  #
  # - the `=` operator if compared with a literal
  #
  # ```
  # query.having({keyword: "hello"}) # having keyword = 'hello'
  # ```
  #
  # - the `IN` operator if compared with an array:
  #
  # ```
  # query.having({x: [1, 2]}) # having x in (1, 2)
  # ```
  #
  # - the `>=` and `<=` | `<` if compared with a range:
  #
  # ```
  # query.having({x: (1..4)})  # having x >= 1 AND x <= 4
  # query.having({x: (1...4)}) # having x >= 1 AND x < 4
  # query.having({x: (1..)})   # having x >= 1
  # query.having({x: (..10)})  # having x <= 10
  # query.having({x: (...10)}) # having x < 10
  # ```
  #
  # - You also can put another select query as argument:
  #
  # ```
  # query.having({x: another_select}) # having x IN (SELECT ... )
  # ```
  def having(conditions : NamedTuple | Hash(String, Lustra::SQL::Any))
    conditions.each do |k, v|
      k = Lustra::Expression::Node::Variable.new(k.to_s)

      @havings <<
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

  # Build SQL `having` interpolating `:keyword` with the NamedTuple passed in argument.
  #
  # ```
  # having("id = :id OR date >= :start", id: 1, start: 1.day.ago)
  # # having id = 1 AND date >= '201x-xx-xx ...'
  # ```
  def having(template : String, **tuple)
    having(Lustra::Expression::Node::Raw.new(Lustra::SQL.raw(template, **tuple)))
  end

  # Build SQL `having` condition using a template string and
  # interpolating `?` characters with parameters given in a tuple or array.
  #
  # ```
  # having("x = ? OR y = ?", 1, "l'eau") # having x = 1 OR y = 'l''eau'
  # ```
  #
  # Raise error if there's not enough parameters to cover all the `?` placeholders
  def having(template : String, *args)
    having(Lustra::Expression::Node::Raw.new(Lustra::SQL.raw(template, *args)))
  end

  # Build SQL `or_having` condition using a Lustra::Expression::Node
  #
  # ```
  # query.or_having(Lustra::Expression::Node::InArray.new("id", ['1', '2', '3', '4']))
  # # Note: in this example, InArray node use unsafe strings
  # ```
  #
  # If useful for moving a having clause from a request to another one:
  #
  # ```
  # query1.or_having { a == b } # having a = b
  # ```
  #
  # ```
  # query2.or_having(query1.havings[0]) # having a = b
  # ```
  def or_having(node : Lustra::Expression::Node)
    return having(node) if @havings.empty?

    # Optimisation: if we have a OR Array as root, we use it and append directly the element.
    if @havings.size == 1 &&
       (n = @havings.first) &&
       n.is_a?(Lustra::Expression::Node::NodeArray) &&
       n.link == "OR"
      n.expression << node
    else
      # Concatenate the old clauses in a list of AND conditions
      if @havings.size == 1
        old_clause = @havings.first
      else
        old_clause = Lustra::Expression::Node::NodeArray.new(@havings, "AND")
      end

      @havings.clear
      @havings << Lustra::Expression::Node::NodeArray.new([old_clause, node], "OR")
    end

    change!
  end

  def or_having(template : String, **named_tuple)
    or_having(Lustra::Expression::Node::Raw.new(Lustra::Expression.raw("(#{template})", **named_tuple)))
  end

  def or_having(template : String, *args)
    or_having(Lustra::Expression::Node::Raw.new(Lustra::Expression.raw("(#{template})", *args)))
  end

  # Build SQL `having` condition using the Expression engine.
  #
  # ```
  # query.or_having { id == 1 }
  # ```
  def or_having(&)
    or_having(Lustra::Expression.ensure_node!(with Lustra::Expression.new yield))
  end

  # Clear all the having clauses and return `self`
  def clear_havings
    @havings.clear

    change!
  end

  # :nodoc:
  protected def print_havings
    {"HAVING ", @havings.join(" AND ", &.resolve)}.join unless @havings.empty?
  end
end
