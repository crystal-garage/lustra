require "./relations/*"

# ```
# class Model
#   include Lustra::Model
#
#   has_many posts : Post, foreign_key: Model.underscore_name + "_id", no_cache : false
#
#   has_one passport : Passport
#   has_many posts
# end
# ```
module Lustra::Model::HasRelations
  macro included # In Lustra::Model
    macro included # In RealModel
      # :nodoc:
      RELATIONS = {} of Nil => Nil
    end
  end

  # The method `has_one` declares a 1 to [0,1] relation where the current
  # model's primary key is stored in the foreign table.
  # `primary_key` method (default: `self#__pkey__`) and `foreign_key` method
  # (default: table_name in singular, plus "_id" appended)
  # can be redefined.
  #
  # Example:
  #
  # ```
  # model Passport
  #   column id : Int32, primary : true
  #   has_one user : User # It assumes the table `users` has a column `passport_id`
  # end
  #
  # model Passport
  #   column id : Int32, primary : true
  #   has_one owner : User # It assumes the table `users` have a column `passport_id`
  # end
  # ```
  macro has_one(
    name,
    foreign_key = nil,
    primary_key = nil,
    no_cache = false,
    polymorphic = false,
    foreign_key_type = nil,
    autosave = false,
  )
    {%
      foreign_key = foreign_key.id if foreign_key.is_a?(SymbolLiteral) || foreign_key.is_a?(StringLiteral)
      primary_key = primary_key.id if primary_key.is_a?(SymbolLiteral) || primary_key.is_a?(StringLiteral)

      RELATIONS[name.var.id] = {
        relation_type: :has_one,

        type: name.type,

        foreign_key: foreign_key,
        primary_key: primary_key,
        no_cache:    no_cache,
      }
    %}
  end

  # Has Many and Has One are relations where the model shares its primary key
  # into a foreign table. In our example above, we can assume that a User has
  # many Posts as author.
  #
  # Basically, for each `belongs_to` declaration, you must have a `has_many` or
  # `has_one` declaration on the other model.
  #
  # While a `has_many` relation returns a list of models, `has_one` returns only
  # one model when called.
  #
  # Example:
  #
  # ```
  # class User
  #   include Lustra::Model
  #
  #   has_many posts : Post, foreign_key: "author_id"
  # end
  # ```
  macro has_many(
    name,
    through = nil,
    foreign_key = nil,
    own_key = nil,
    primary_key = nil,
    no_cache = false,
    polymorphic = false,
    foreign_key_type = nil,
    autosave = false,
    as polymorphic_as = nil,
  )
    {%
      if through != nil
        own_key = own_key.id if own_key.is_a?(SymbolLiteral) || own_key.is_a?(StringLiteral)
        foreign_key = foreign_key.id if foreign_key.is_a?(SymbolLiteral) || foreign_key.is_a?(StringLiteral)
        foreign_key_type = foreign_key_type.id if foreign_key_type.is_a?(SymbolLiteral) || foreign_key_type.is_a?(StringLiteral)

        RELATIONS[name.var.id] = {
          relation_type: :has_many_through,
          type:          name.type,

          through: through,
          own_key: own_key,

          foreign_key:      foreign_key,
          foreign_key_type: foreign_key_type,

          polymorphic: polymorphic,
          autosave:    autosave,
        }
      else
        foreign_key = foreign_key.id if foreign_key.is_a?(SymbolLiteral) || foreign_key.is_a?(StringLiteral)
        primary_key = primary_key.id if primary_key.is_a?(SymbolLiteral) || primary_key.is_a?(StringLiteral)
        polymorphic_as = polymorphic_as.id if polymorphic_as.is_a?(SymbolLiteral) || polymorphic_as.is_a?(StringLiteral)
        foreign_key_type = foreign_key_type.id if foreign_key_type.is_a?(SymbolLiteral) || foreign_key_type.is_a?(StringLiteral)

        RELATIONS[name.var.id] = {
          relation_type: :has_many,
          type:          name.type,

          foreign_key:      foreign_key,
          primary_key:      primary_key,
          as:               polymorphic_as,
          foreign_key_type: foreign_key_type,

          no_cache:    no_cache,
          polymorphic: polymorphic,
          autosave:    autosave,
        }
      end
    %}
  end

  # ```
  # class Model
  #   include Lustra::Model
  #
  #   belongs_to user : User, foreign_key: "the_user_id"
  # end
  # ```
  macro belongs_to(
    name,
    foreign_key = nil,
    no_cache = false,
    primary = false,
    foreign_key_type = Int64,
    touch = nil,
    counter_cache = nil,
    polymorphic = false,
    polymorphic_type = nil,
  )
    {%
      foreign_key = foreign_key.id if foreign_key.is_a?(SymbolLiteral) || foreign_key.is_a?(StringLiteral)
      touch = touch.id if touch.is_a?(SymbolLiteral) || touch.is_a?(StringLiteral)
      polymorphic_type = polymorphic_type.stringify if polymorphic_type.is_a?(SymbolLiteral)

      nilable = false
      polymorphic_types = nil

      if name.type.is_a?(Union)
        # We cannot use here call `resolve` as some of the references
        # might not yet have been defined
        types = name.type.types.map { |x| "#{x.id}" }
        # So we check for the nil type if it exists
        nilable = types.includes?("Nil") || types.includes?("::Nil")

        if polymorphic
          polymorphic_types = name.type.types.reject { |x| "#{x.id}" == "Nil" || "#{x.id}" == "::Nil" }
          type = polymorphic_types.map(&.id).join(" | ").id
        else
          type = name.type.types.first
        end
      else
        type = name.type
        polymorphic_types = [type] if polymorphic
      end

      if nilable
        unless foreign_key_type.resolve.nilable?
          foreign_key_type = "#{foreign_key_type.id}?".id
        end
      end

      RELATIONS[name.var.id] = {
        relation_type:     :belongs_to,
        type:              type,
        foreign_key:       foreign_key,
        nilable:           nilable,
        primary:           primary,
        no_cache:          no_cache,
        foreign_key_type:  foreign_key_type,
        touch:             touch,
        counter_cache:     counter_cache,
        polymorphic:       polymorphic,
        polymorphic_types: polymorphic_types,
        polymorphic_type:  polymorphic_type,
      }
    %}
  end

  # :nodoc:
  # Generate the relations by calling the macro
  macro __generate_relations__
    {% for name, settings in RELATIONS %}
      {% if settings[:relation_type] == :belongs_to %}
        Relations::BelongsToMacro.generate(
          {{ @type }},
          {{ name }},
          {{ settings[:type] }},
          {{ settings[:nilable] }},
          {{ settings[:foreign_key] }},
          {{ settings[:primary] }},
          {{ settings[:no_cache] }},
          {{ settings[:foreign_key_type] }},
          {{ settings[:touch] }},
          {{ settings[:counter_cache] }},
          {{ settings[:polymorphic] }},
          {{ settings[:polymorphic_types] }},
          {{ settings[:polymorphic_type] }}
        )
      {% elsif settings[:relation_type] == :has_many %}
        Relations::HasManyMacro.generate(
          {{ @type }},
          {{ name }},
          {{ settings[:type] }},
          {{ settings[:foreign_key] }},
          {{ settings[:primary_key] }},
          {{ settings[:as] }},
          {{ settings[:autosave] }}
        )
      {% elsif settings[:relation_type] == :has_many_through %}
        Relations::HasManyThroughMacro.generate(
          {{ @type }},
          {{ name }},
          {{ settings[:type] }},
          {{ settings[:through] }},
          {{ settings[:own_key] }},
          {{ settings[:foreign_key] }},
          {{ settings[:autosave] }}
        )
      {% elsif settings[:relation_type] == :has_one %}
        Relations::HasOneMacro.generate(
          {{ @type }},
          {{ name }},
          {{ settings[:type] }},
          {{ settings[:foreign_key] }},
          {{ settings[:primary_key] }}
        )
      {% else %}
        {% raise "I don't know this relation: #{settings[:relation_type]}" %}
      {% end %}
    {% end %}
  end
end
