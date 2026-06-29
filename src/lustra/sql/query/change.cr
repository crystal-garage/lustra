module Lustra::SQL::Query::Change
  # This method is called every time the request changes.
  # By default, this does nothing and returns `self`. However, it can be
  # reimplemented to change behavior when the query changes.
  #
  # For example, `Lustra::Model::Collection` uses it to discard collection cache.
  def change! : self
    self
  end
end
