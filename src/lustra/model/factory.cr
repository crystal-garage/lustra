require "./factories/**"

module Lustra::Model::Factory
  FACTORIES = {} of String => Lustra::Model::Factory::Base # Used during compilation time

  macro add(type, factory)
    {% Lustra::Model::Factory::FACTORIES[type] = factory %}
  end

  def self.build(
    type : String,
    h : Hash,
    cache : Lustra::Model::QueryCache? = nil,
    persisted = false,
    fetch_columns = false,
  ) : Lustra::Model
    factory = FACTORIES[type].as(Base)

    factory.build(h, cache, persisted, fetch_columns)
  end

  def self.build(
    type : T.class,
    h : Hash,
    cache : Lustra::Model::QueryCache? = nil,
    persisted = false,
    fetch_columns = false,
  ) : T forall T
    build(T.name, h, cache, persisted, fetch_columns).as(T)
  end
end
