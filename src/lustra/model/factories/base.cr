module Lustra::Model::Factory
  module Base
    abstract def build(h : Hash(String, ::Lustra::SQL::Any),
                       cache : Lustra::Model::QueryCache? = nil,
                       persisted : Bool = false,
                       fetch_columns : Bool = false) : Lustra::Model
  end
end
