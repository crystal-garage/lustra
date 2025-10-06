require "./**"

module Lustra::Model
  include Lustra::Model::FullTextSearchable
end

# Reopen Table to add the helpers
class Lustra::Migration::Table < Lustra::Migration::Operation
  include Lustra::Migration::FullTextSearchableTableHelpers
end

module Lustra::Migration::Helper
  include Lustra::Migration::FullTextSearchableHelpers
end
