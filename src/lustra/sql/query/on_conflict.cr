require "./where"

module Lustra::SQL::Query::OnConflict
  getter on_conflict_condition : String | OnConflictWhereClause | Bool = false
  getter on_conflict_action : String | Lustra::SQL::UpdateQuery = "NOTHING"

  # Conflict index target and its optional predicate.
  class OnConflictWhereClause
    include Query::Where

    getter target : String?

    def initialize(@target : String? = nil)
      target = @target
      unless target && target.lstrip.starts_with?("(")
        raise QueryBuildingError.new("A conflict index predicate requires an explicit column or expression target, such as on_conflict(\"(email)\")")
      end
      @wheres = [] of Lustra::Expression::Node
    end

    def to_s
      "#{@target} #{print_wheres}"
    end

    def change!
    end
  end

  def do_conflict_action(str)
    @on_conflict_action = "#{str}"
    change!
  end

  def do_update(&)
    action = Lustra::SQL::UpdateQuery.new(nil)
    yield(action)
    @on_conflict_action = action
    change!
  end

  def do_nothing
    @on_conflict_action = "NOTHING"
    change!
  end

  def on_conflict(constraint : String | Bool | OnConflictWhereClause = true)
    @on_conflict_condition = constraint
    change!
  end

  # Add an index predicate to a previously supplied conflict target.
  # Use do_update { |update| update.where(...) } for an update condition.
  def on_conflict(&)
    target =
      case current = @on_conflict_condition
      when String
        current
      when OnConflictWhereClause
        current.target
      end

    condition = OnConflictWhereClause.new(target)
    condition.where(
      Lustra::Expression.ensure_node!(with Lustra::Expression.new yield)
    )
    @on_conflict_condition = condition
    change!
  end

  def conflict?
    !!@on_conflict_condition
  end

  def clear_conflict
    @on_conflict_condition = false
  end

  protected def print_on_conflict(o : Array)
    if c = @on_conflict_condition
      o << "ON CONFLICT"

      unless c == true
        o << c.to_s
      end

      a = @on_conflict_action
      o << "DO" << (a.is_a?(String) ? a.to_s : a.to_sql)
    end
  end
end
