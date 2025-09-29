require "admiral"

require "./core"
require "./cli/command"
require "./cli/migration"
require "./cli/seed"
require "./cli/generator"

module Lustra
  module CLI
    def self.run
      Lustra::CLI::Base.run
    end

    class Base < Admiral::Command
      include Lustra::CLI::Command

      define_version Lustra::VERSION
      define_help

      register_sub_command migrate, type: Lustra::CLI::Migration
      register_sub_command generate, type: Lustra::CLI::Generator
      register_sub_command seed, type: Lustra::CLI::Seed

      def run_impl
        STDOUT.puts help
      end
    end
  end

  # Check for the CLI. If the CLI is not triggered, yield the block passed as parameter
  def self.with_cli(&)
    if ARGV.size > 0 && ARGV[0] == "lustra"
      ARGV.shift
      Lustra::CLI.run
    else
      yield
    end
  end
end
