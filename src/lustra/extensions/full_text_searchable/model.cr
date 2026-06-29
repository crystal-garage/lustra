require "./tsvector"

# The full-text search plugin offers full integration with PostgreSQL `tsvector`
# capabilities.
#
# It allows you to query models through the text content of one or multiple fields.
#
# ### The blog example
#
# Let's assume we have a blog and want to implement full text search over title and content:
#
# ```
# create_table "posts" do |t|
#   t.column :title, :string, null: false
#   t.column :content, :string, null: false
#
#   t.full_text_searchable on: [{"title", 'A'}, {"content", 'C'}]
# end
# ```
#
# This migration will create a third column named `full_text_vector` of type
# `tsvector`, a GIN index, a trigger, and a function to update this column
# automatically.
#
# In the `on` option, `{"title", 'A'}` means that "title" is searchable with
# priority weight "A". This tells PostgreSQL that title content is more
# meaningful than the article content itself.
#
# Now, let's build some models:
#
# ```
#
#   model Post
#     include Lustra::Model
#     #...
#
#     full_text_searchable
#   end
#
#   Post.create!({title: "About poney", content: "Poney are cool"})
#   Post.create!({title: "About dog and cat", content: "Cat and dog are cool. But not as much as poney"})
#   Post.create!({title: "You won't believe: She raises her poney like as star!", content: "She's cool because poney are cool"})
# ```
#
# Search is now straightforward:
#
# ```
# Post.query.search("poney") # Returns all matching articles.
# ```
#
# Search calls can be chained:
#
# ```
# user = User.find_by! { email == "some_email@example.com" }
# Post.query.from_user(user).search("orm")
# ```
#
# ### Additional parameters
#
# #### `catalog`
#
# Select the catalog to use to build the tsquery. By default, `pg_catalog.english` is used.
#
# ```
# # in your migration:
# t.full_text_searchable on: [{"title", 'A'}, {"content", 'C'}], catalog: "pg_catalog.french"
#
# # in your model
# full_text_searchable catalog: "pg_catalog.french"
# ```
#
# Note: For now, Lustra does not offer dynamic catalog selection for multilingual
# services. If your app needs this feature, open an issue.
#
# #### `trigger_name`, `function_name`
#
# In migrations, you can change the generated trigger and function names using
# these two keys.
#
# #### `dest_field`
#
# The field created in the database that will contain your tsvector. Default is
# `full_text_vector`.
#
# ```
# # in your migration
# t.full_text_searchable on: [{"title", 'A'}, {"content", 'C'}], dest_field: "tsv"
#
# # in your model
# full_text_searchable "tsv"
# ```
module Lustra::Model::FullTextSearchable
  # Set this model as searchable using tsvector
  macro full_text_searchable(through = "full_text_vector", catalog = "pg_catalog.english", scope_name = "search")
    column( {{ through.id }} : Lustra::TSVector, presence: false)

    scope "{{ scope_name.id }}" do |str|
      table = self.item_class.table
      where {
        op(
          var(table, "{{ through.id }}"),
          to_tsquery({{ catalog }}, Lustra::Model::FullTextSearchable.to_tsq(str)),
          "@@"
        )
      }
    end
  end

  # :nodoc:
  # Split a chain written by a user
  # The problem comes from the usage of `'` in languages like French
  # which can easily break a tsvector query
  #
  # ameba:disable Metrics/CyclomaticComplexity (Is parser)
  private def self.split_to_exp(text)
    last_char : Char? = nil
    quote_char : Char? = nil
    modifier : Symbol? = nil

    currtoken = [] of Char
    arr_tokens = [] of {Symbol?, String}

    text.each_char do |c|
      case c
      when '\''
        if quote_char.nil?
          if last_char.to_s =~ /[a-z0-9]/i # Avoid french word e.g. "l'avion"
            currtoken << c
          else
            quote_char = '\''
          end
        elsif quote_char == '\''
          arr_tokens << {modifier, currtoken.join}
          currtoken.clear
          modifier = nil
          quote_char = nil
        else
          currtoken << c
        end
      when ' '
        if quote_char.nil?
          unless currtoken.empty?
            arr_tokens << {modifier, currtoken.join}
            currtoken.clear
          end
          modifier = nil
        else
          currtoken << c
        end
      when '"'
        if quote_char.nil?
          quote_char = '"'
        elsif quote_char == '"'
          arr_tokens << {modifier, currtoken.join}
          currtoken.clear
          modifier = nil
          quote_char = nil
        else
          currtoken << c
        end
      when '-'
        if currtoken.empty? && quote_char.nil? # When first char of the token == `-`
          modifier = :-
        else
          currtoken << c
        end
      else
        currtoken << c
      end

      last_char = c
    end

    unless currtoken.empty?
      arr_tokens << {modifier, currtoken.join}
    end

    arr_tokens
  end

  # Parse client side text and generate string ready to be ingested by PG's `to_tsquery`.
  #
  # Author note: pg `to_tsquery` is awesome but can easily fail to parse.
  #   `search` uses a text_to_search wrapper to ensure the request is understood
  #   and always produces a legal string for `to_tsquery`.
  # This is a good helper to use with end-user input.
  #
  # However, this helper can be improved, as it doesn't use all the features
  # of tsvector (parentheses, OR operator, etc.).
  def self.to_tsq(text)
    text = text.gsub(/\+/, " ")
    tokens = split_to_exp(text)

    tokens.join(" & ") do |(modifier, value)|
      if modifier == :-
        "!" + Lustra::Expression[value]
      else
        Lustra::Expression[value]
      end
    end
  end
end
