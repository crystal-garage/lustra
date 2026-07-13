module Lustra::SQL::Query::ConditionBuilder
  private def condition_node(key, value) : Lustra::Expression::Node
    variable = Lustra::Expression::Node::Variable.new(key.to_s)

    case value
    when Array
      Lustra::Expression::Node::InArray.new(variable, value.map { |item| Lustra::Expression[item] })
    when Lustra::SQL::SelectBuilder
      Lustra::Expression::Node::InSelect.new(variable, value)
    when Range
      range_begin = value.begin.nil? ? nil : Lustra::Expression[value.begin]
      range_end = value.end.nil? ? nil : Lustra::Expression[value.end]
      Lustra::Expression::Node::InRange.new(variable, range_begin..range_end, value.exclusive?)
    else
      Lustra::Expression::Node::DoubleOperator.new(
        variable,
        Lustra::Expression::Node::Literal.new(value),
        value.nil? ? "IS" : "="
      )
    end
  end

  private def append_or_condition(clauses : Array(Lustra::Expression::Node), node : Lustra::Expression::Node)
    if clauses.size == 1 &&
       (current = clauses.first).is_a?(Lustra::Expression::Node::NodeArray) &&
       current.link == "OR"
      current.expression << node
    else
      old_clause = if clauses.size == 1
                     clauses.first
                   else
                     Lustra::Expression::Node::NodeArray.new(clauses, "AND")
                   end

      clauses.clear
      clauses << Lustra::Expression::Node::NodeArray.new([old_clause, node], "OR")
    end
  end
end
