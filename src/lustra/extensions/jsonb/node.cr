module Lustra::Expression::JSONB::Node
  def jsonb_key_exists?(key : String)
    Lustra::Expression::Node::DoubleOperator.new(self, Lustra::Expression::Node::Literal.new(key), "?")
  end

  # :no_doc:
  private def _jsonb_keys_exists(keys : Array(T), op) forall T
    Lustra::Expression::Node::DoubleOperator.new(self,
      Lustra::Expression::Node::PGArray(T).new(keys),
      op)
  end

  def jsonb_any_key_exists?(keys : Array(T)) forall T
    _jsonb_keys_exists(keys, "?|")
  end

  def jsonb_all_keys_exists?(keys : Array(T)) forall T
    _jsonb_keys_exists(keys, "?&")
  end

  def jsonb(key : String)
    Lustra::Expression::Node::JSONB::Field.new(self, key)
  end
end
