require "./base"

module Lustra::Model::Factory
  class SimpleFactory(T)
    include Base

    def build(h : Hash(String, ::Lustra::SQL::Any),
              cache : Lustra::Model::QueryCache? = nil,
              persisted : Bool = false,
              fetch_columns : Bool = false) : Lustra::Model
      T.new(h, cache, persisted, fetch_columns).as(Lustra::Model)
    end
  end
end
