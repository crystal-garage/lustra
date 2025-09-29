require "../../src/lustra"

def initdb
  Lustra::SQL.init("postgres://postgres@localhost/lustra_spec")
end

initdb

class UpdatePasswordField3
  include Lustra::Migration

  def change(dir)
    dir.up { puts "3:up" }
    dir.down { puts "3:down" }
  end
end

class CreateDatabase1
  include Lustra::Migration

  def change(dir)
    dir.up { puts "1:up" }
    dir.down { puts "1:down" }
  end
end

class ApplyChange2
  include Lustra::Migration

  def change(dir)
    dir.up { puts "2:up" }
    dir.down { puts "2:down" }
  end
end

Lustra.seed do
  puts "This is a seed"
end

Lustra.with_cli do
  puts "Usage: crystal sample/cli/cli.cr -- lustra [args]"
end
