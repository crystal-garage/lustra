class Lustra::CLI::Seed < Admiral::Command
  include Lustra::CLI::Command

  define_help description: "Seed the database with seed data"

  def run_impl
    Lustra.apply_seeds
  end
end
