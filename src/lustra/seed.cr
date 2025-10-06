module Lustra
  @@seed_list = [] of ->

  # Register a seed block.
  # this block will be called by `Lustra.apply_seeds`
  # or conveniently by the CLI
  # using `$cli_cmd migrate seeds`
  def self.seed(&block)
    @@seed_list << block
  end

  def self.apply_seeds
    Lustra::SQL.transaction { @@seed_list.each(&.call) }
  end
end
