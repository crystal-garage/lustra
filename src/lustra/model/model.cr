require "../sql"
require "./collection"
require "./column"
require "./modules/**"
require "./converters/**"
require "./validation/**"
require "./factory"

module Lustra::Model
  include Lustra::ErrorMessages
  include Lustra::Model::Connection
  include Lustra::Model::HasHooks
  include Lustra::Model::HasColumns
  include Lustra::Model::HasTimestamps
  include Lustra::Model::HasSerialPkey
  include Lustra::Model::HasSaving
  include Lustra::Model::HasValidation
  include Lustra::Model::HasRelations
  include Lustra::Model::HasScope
  include Lustra::Model::ClassMethods
  include Lustra::Model::HasFactory
  include Lustra::Model::Initializer
  include Lustra::Model::JSONDeserialize

  getter cache : Lustra::Model::QueryCache?

  # Alias method for primary key.
  #
  # If `Model#id` IS the primary key, then calling `Model#__pkey__` is exactly the same as `Model#id`.
  #
  # This method exists to tremendously simplify the meta-programming code.
  # If no primary key has been setup to this model, raise an exception.
  def __pkey__
    raise lack_of_primary_key(self.class.name)
  end

  # We use here included for errors purpose.
  # The overload are shown in this case, but not in the case the constructors
  # are directly defined without the included block.
  macro included
    {% raise "Do NOT include Lustra::Model on struct-like objects.\n" +
             "It would behave very strangely otherwise." unless @type < Reference %}    # <~ Models are mutable objects;
                                                                                        # they do not work with structures which are immuable

    extend Lustra::Model::HasHooks::ClassMethods

    getter cache : Lustra::Model::QueryCache?

    def initialize
      @persisted = false
    end

    def initialize(h : Hash(String, _), @cache : Lustra::Model::QueryCache? = nil, @persisted = false, fetch_columns = false)
      @attributes.merge!(h) if fetch_columns

      reset(h)
    end

    def initialize(json : ::JSON::Any, @cache : Lustra::Model::QueryCache? = nil, @persisted = false)
      reset(json.as_h)
    end

    def initialize(t : NamedTuple, @persisted = false)
      reset(t)
    end

    # Force to clean-up the caches for the relations
    # connected to this model.
    def invalidate_caching : self
      @cache = nil
      self
    end

    # :nodoc:
    # This is a tricky method which is overriden by inherited models.
    #
    # The problem is usage of static array initialisation under `finalize` macro; they are initialized
    # AFTER the main code is executed, preventing it to work properly.
    #
    # The strategy here is to execute the static array initialization under a method and execute this method
    # before main.
    #
    # Then to redefine this method in the finalize block. The current behavior seems to be a crystal compiler bug
    # and should be fixed in near future.
    def self.__main_init__
    end
  end
end

require "./reflection/**"
