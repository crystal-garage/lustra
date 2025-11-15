require "./base"

# Minimal PostgreSQL range parsing utilities tailored for Lustra converters.
# This supports basic numeric and time ranges in the form: "[1,10)", "(2020-01-01,2020-12-31]", and handles "-infinity"/"infinity".
def parse_pg_range(str : String, &block)
  return nil if str.empty? || str == "empty"

  match = str.match(/^([\[\(])\s*(.*?)\s*,\s*(.*?)\s*([\)\]])$/)
  unless match
    raise "Invalid range format: #{str}"
  end

  left_incl = match[1] == "["
  right_incl = match[4] == "]"
  left_s = match[2]
  right_s = match[3]

  left_val = (left_s == "" || left_s == "-infinity") ? nil : yield(left_s)
  right_val = (right_s == "" || right_s == "infinity") ? nil : yield(right_s)

  # Crystal Range only supports an exclusive end flag; use right_exclusive accordingly.
  right_exclusive = !right_incl

  Range.new(left_val, right_val, right_exclusive)
end

def pg_range_to_string(r)
  left = r.begin.nil? ? "-infinity" : r.begin.to_s
  right = r.end.nil? ? "infinity" : r.end.to_s
  left_bracket = "[" # we always output inclusive start; PostgreSQL allows exclusive start but Crystal Range can't represent it
  right_bracket = r.excludes_end? ? ")" : "]"
  "#{left_bracket}#{left},#{right}#{right_bracket}"
end

module Lustra::Model::Converter::RangeConverterInt32
  def self.to_column(x) : Range(Int32?, Int32?)?
    case x
    when Nil
      nil
    when Range(Int32?, Int32?)
      x
    when String
      r = parse_pg_range(x) { |s| s.to_i32 }
      r
    else
      nil
    end
  end

  def self.to_db(x)
    case x
    when Nil
      nil
    when Range
      r = x
      left = r.begin.nil? ? "-infinity" : r.begin.to_s
      right = r.end.nil? ? "infinity" : r.end.to_s
      right_bracket = r.excludes_end? ? ")" : "]"
      "[#{left},#{right}#{right_bracket}"
    else
      nil
    end
  end
end

module Lustra::Model::Converter::RangeConverterInt64
  def self.to_column(x) : Range(Int64?, Int64?)?
    case x
    when Nil
      nil
    when Range(Int64?, Int64?)
      x
    when String
      r = parse_pg_range(x) { |s| s.to_i64 }
      r
    else
      nil
    end
  end

  def self.to_db(x)
    case x
    when Nil
      nil
    when Range
      r = x
      left = r.begin.nil? ? "-infinity" : r.begin.to_s
      right = r.end.nil? ? "infinity" : r.end.to_s
      right_bracket = r.excludes_end? ? ")" : "]"
      "[#{left},#{right}#{right_bracket}"
    else
      nil
    end
  end
end

module Lustra::Model::Converter::RangeConverterPGNumeric
  def self.to_column(x) : Range(PG::Numeric?, PG::Numeric?)?
    case x
    when Nil
      nil
    when Range(PG::Numeric?, PG::Numeric?)
      x
    when String
      r = parse_pg_range(x) { |s| BigDecimal.new(s) }
      r
    else
      nil
    end
  end

  def self.to_db(x)
    case x
    when Nil
      nil
    when Range
      r = x
      left = r.begin.nil? ? "-infinity" : r.begin.to_s
      right = r.end.nil? ? "infinity" : r.end.to_s
      right_bracket = r.excludes_end? ? ")" : "]"
      "[#{left},#{right}#{right_bracket}"
    else
      nil
    end
  end
end

module Lustra::Model::Converter::RangeConverterTime
  def self.to_column(x) : Range(Time?, Time?)?
    case x
    when Nil
      nil
    when Range(Time?, Time?)
      x
    when String
      r = parse_pg_range(x) do |s|
        # Try local parse for non-RFC formats, fall back to RFC_3339
        case s
        when /[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}.[0-9]+/
          Time.parse_local(s, "%F %X.%L")
        else
          Time::Format::RFC_3339.parse(s)
        end
      end
      r
    else
      nil
    end
  end

  def self.to_db(x)
    case x
    when Nil
      nil
    when Range
      r = x

      left = r.begin.nil? ? "-infinity" : r.begin.to_s
      right = r.end.nil? ? "infinity" : r.end.to_s

      right_bracket = r.excludes_end? ? ")" : "]"

      "[#{left},#{right}#{right_bracket}"
    else
      nil
    end
  end
end

module Lustra::Model::Converter
  add_converter("Range(Int32 | Nil, Int32 | Nil)", Lustra::Model::Converter::RangeConverterInt32)
  add_converter("Range(Int64 | Nil, Int64 | Nil)", Lustra::Model::Converter::RangeConverterInt64)
  add_converter("Range(Time | Nil, Time | Nil)", Lustra::Model::Converter::RangeConverterTime)
end
