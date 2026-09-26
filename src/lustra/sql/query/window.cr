module Lustra::SQL::Query::Window
  alias WindowDeclaration = {String, String}

  # eq. WINDOW window_name AS ( window_definition )
  getter windows : Array(WindowDeclaration)

  def window(windows : NamedTuple)
    windows.each do |k, v|
      @windows << {k.to_s, v.to_s}
    end

    change!
  end

  def window(name, value)
    @windows << {name.to_s, value.to_s}

    change!
  end

  def clear_windows
    @windows.clear

    change!
  end

  def print_windows
    return "" if @windows.empty?

    "WINDOW " + @windows.join(", ") do |name, value|
      {Lustra::SQL.escape(name), " AS ", value}.join
    end
  end
end
