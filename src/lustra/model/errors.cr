module Lustra::Model
  class Error < Exception; end

  class InvalidError < Error
    getter model : Lustra::Model

    def initialize(@model : Lustra::Model)
      super("The model `#{@model.class}` is invalid:\n#{model.print_errors}")
    end
  end

  class ReadOnlyError < Error
    getter model : Lustra::Model

    def initialize(@model : Lustra::Model)
      super(
        "The model `#{@model.class}` is read-only and cannot be saved. " \
        "Read-only models are commonly used for database views or system catalogs. " \
        "Remove `self.read_only = true` if this model should be writable."
      )
    end
  end
end
