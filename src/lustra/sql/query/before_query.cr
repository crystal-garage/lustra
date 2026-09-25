module Lustra::SQL::Query::BeforeQuery
  macro included
    @before_query_triggers : Array(Lustra::SQL::SelectBuilder -> Nil)

    # Run a callback before fetching results, in registration order.
    # Callbacks are cleared once all have completed successfully, before SQL
    # execution. If a callback raises, fetching stops and callbacks remain
    # registered for the next attempt. `execute` does not run these callbacks.
    #
    # ```
    # calls = 0
    # query = Lustra::SQL.select("1").before_query { calls += 1 }
    # query.to_a
    # pp calls # 1
    # query.to_a
    # pp calls # Still 1: the callback was cleared after the first fetch.
    # ```
    def before_query(&block : -> Nil)
      before_query_with_context { |_| block.call }
    end

    # :nodoc:
    # Pass the executing query so copied hooks do not capture the original query.
    def before_query_with_context(&block : Lustra::SQL::SelectBuilder -> Nil)
      @before_query_triggers << block

      self
    end

    # Remove callbacks registered to run before the query executes.
    def clear_before_query_triggers
      @before_query_triggers = [] of Lustra::SQL::SelectBuilder -> Nil

      self
    end

    # :nodoc:
    protected def trigger_before_query
      @before_query_triggers.each &.call(self)
      @before_query_triggers.clear

      self
    end
  end
end
