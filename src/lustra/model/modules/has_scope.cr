module Lustra::Model::HasScope
  macro included
    # Storage for default scope block at class level
    @@__default_scope_block__ : Proc(Nil)? = nil

    # A scope allow you to filter in a very human way a set of data.
    #
    # Usage:
    #
    # ```
    # scope("admin") { where({role: "admin"}) }
    # ```
    #
    # for example, instead of writing:
    #
    # ```
    # User.query.where { (role == "admin") & (active == true) }
    # ```
    #
    # You can write:
    #
    # ```
    # User.admin.active
    # ```
    #
    # Scope can be used for other purpose than just filter (e.g. ordering),
    # but I would not recommend it.
    macro scope(name, &block)
      \{% parameters = "" %}
      \{% for arg, idx in block.args %}
        \{% parameters = parameters + "*" if (block.splat_index && idx == block.splat_index) %}
        \{% parameters = parameters + "#{arg}" %}
        \{% parameters = parameters + ", " unless (idx == block.args.size - 1) %}
      \{% end %}
      \{% parameters = parameters.id %}

      def self.\{{name.id}}(\{{parameters}})
        query.\{{name.id}}(\{{parameters}})
      end

      class Collection < Lustra::Model::CollectionBase(\{{@type}});
        def \{{name.id}}(\{{parameters}})
          \{{yield}}

          return self
        end
      end
    end

    # Define a default scope that will be automatically applied to all queries.
    # Useful for soft deletes, multi-tenancy, or any filter that should always apply.
    #
    # **Warning:** Default scopes can be confusing as they're implicit.
    # Use sparingly and document clearly.
    #
    # Usage:
    #
    # ```
    # class Post
    #   include Lustra::Model
    #
    #   column deleted_at : Time?
    #
    #   default_scope { where { deleted_at == nil } }
    # end
    #
    # Post.query       # SELECT * FROM posts WHERE deleted_at IS NULL
    # Post.query.first # Also applies default scope
    # ```
    #
    # To bypass default scope, use `unscoped`:
    #
    # ```
    # Post.query.unscoped       # SELECT * FROM posts (no default scope)
    # Post.query.unscoped.count # Works with any query method
    # ```
    macro default_scope(&block)
      class Collection < Lustra::Model::CollectionBase(\{{@type}});
        def __apply_default_scope__
          \{{yield}}
          return self
        end

        # Remove default scope from this query chain.
        # Returns a new collection without the default scope applied.
        #
        # ```
        # Post.query.unscoped              # No default scope
        # Post.query.unscoped.count        # Count all records
        # Post.query.where(...).unscoped   # Start fresh without scope
        # ```
        def unscoped
          \{{@type}}.__unscoped_query__
        end
      end
    end
  end
end
