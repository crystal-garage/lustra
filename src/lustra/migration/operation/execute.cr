require "./operation"

module Lustra::Migration
  class Execute < Operation
    def initialize(@sql : String, @irreversible : Bool? = false)
    end

    def up : Array(String)
      [@sql].compact
    end

    def down : Array(String)
      irreversible! if @irreversible
      [@sql].compact
    end
  end
end
