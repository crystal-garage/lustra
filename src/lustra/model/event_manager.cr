# This class manages the storage and execution of model lifecycle callbacks.
# It acts as a singleton that stores callbacks for all models and triggers them
# during appropriate lifecycle events.
#
# Key concepts:
# - `EVENT_CALLBACKS`: Hash storing all registered callbacks by `{class_name, direction, event}`
# - Direction: `:before` or `:after`
# - Events: `:create`, `:update`, `:validate`, `:save`, etc.
#
# Usage: This is used internally by `Lustra::Model::HasHooks`
# Global storage for model lifecycle event management
class Lustra::Model::EventManager
  alias HookFunction = Lustra::Model -> Nil
  alias EventKey = {String, Symbol, Symbol}

  EVENT_CALLBACKS = {} of EventKey => Array(HookFunction)
  INHERITANCE_MAP = {} of String => String

  # Trigger all callbacks for a specific model, direction, and event
  #
  # `klass` - the model class
  # `direction` - `:before` or `:after`
  # `event` - the lifecycle event (`:create`, `:update`, `:validate`, etc.)
  # `mdl` - the model instance
  #
  # Callback execution order:
  # - `:before` callbacks: Last defined -> First defined (reverse order)
  # - `:after` callbacks: First defined -> Last defined (normal order)
  #
  # This ensures that the most recently defined callbacks run first for `:before`
  # and last for `:after`, allowing for proper layering of functionality.
  def self.trigger(klass, direction : Symbol, event : Symbol, mdl : Lustra::Model)
    arr = EVENT_CALLBACKS.fetch({klass.to_s, direction, event}) { [] of HookFunction }

    parent = INHERITANCE_MAP[klass.to_s]?

    if direction == :after
      arr = arr.reverse

      arr.each &.call(mdl)
      trigger(parent, direction, event, mdl) unless parent.nil?
    else
      trigger(parent, direction, event, mdl) unless parent.nil?
      arr.each &.call(mdl)
    end
  end

  # Map the inheritance between models. Events which belongs to parent model are triggered when child model lifecycle
  # actions occurs
  def self.add_inheritance(parent, child)
    INHERITANCE_MAP[child.to_s] = parent.to_s
  end

  # Register a callback for a specific model class, direction, and event
  #
  # `klass` - The model class
  # `direction` - `:before` or `:after`
  # `event` - The lifecycle event (`:create`, `:update`, `:validate`, etc.)
  # `block` - The callback function to execute
  #
  # This is called internally by `Lustra::Model::HasHooks` when you define
  # `before` or `after` callbacks in your model.
  def self.attach(klass, direction : Symbol, event : Symbol, block : HookFunction)
    tuple = {klass.to_s, direction, event}
    arr = EVENT_CALLBACKS.fetch(tuple) { [] of HookFunction }

    arr.push(block)
    EVENT_CALLBACKS[tuple] = arr
  end
end
