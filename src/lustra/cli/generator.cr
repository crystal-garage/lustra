require "option_parser"
require "ecr"

class Lustra::CLI::Generator < Admiral::Command
  include Lustra::CLI::Command

  define_help description: "Generate code automatically"

  def run_impl
    puts help
  end

  macro ecr_to_s(string, opts)
    opts = {{ opts }}
    io = IO::Memory.new
    ECR.embed {{ string }}, io
    io.to_s
  end
end

require "./generators/**"
