# :nodoc:
# PostgreSQL range text preserves empty values and both bound inclusivity flags.
module Lustra::SQL::RangeLiteral
  extend self

  def format(value : PG::Range) : String
    return "empty" if value.empty?
    format_bounds(value, value.lower_inclusive, value.upper_inclusive)
  end

  def format(value : ::Range) : String
    if !value.begin.nil? && value.begin == value.end && value.excludes_end?
      return "empty"
    end
    format_bounds(value, !value.begin.nil?, !value.end.nil? && !value.excludes_end?)
  end

  private def format_bounds(value, lower_inclusive : Bool, upper_inclusive : Bool) : String
    lower = value.begin.try { |bound| format_bound(bound) } || ""
    upper = value.end.try { |bound| format_bound(bound) } || ""
    "#{lower_inclusive ? '[' : '('}#{lower},#{upper}#{upper_inclusive ? ']' : ')'}"
  end

  private def format_bound(value : Time) : String
    value.to_utc.to_rfc3339(fraction_digits: 9)
  end

  private def format_bound(value) : String
    text = value.to_s
    if text.empty? || text.each_char.any? { |char| char.whitespace? || {'"', '\\', ',', '(', ')', '[', ']'}.includes?(char) }
      %("#{text.gsub('\\', "\\\\").gsub('"', "\\\"")}")
    else
      text
    end
  end

  def parse(text : String, type : T.class, & : String -> T?) : PG::Range(T) forall T
    text = text.strip
    return PG::Range(T).empty if text == "empty"
    unless text.size >= 3 && {'[', '('}.includes?(text[0]) && {']', ')'}.includes?(text[-1])
      raise ArgumentError.new("Invalid PostgreSQL range: #{text}")
    end

    bounds = split_bounds(text[1...-1])
    lower = bounds[0].try { |bound| yield bound }
    upper = bounds[1].try { |bound| yield bound }
    PG::Range(T).new(lower, upper,
      lower_inclusive: !lower.nil? && text[0] == '[',
      upper_inclusive: !upper.nil? && text[-1] == ']')
  end

  # Range text uses double quotes and backslashes to escape bound delimiters.
  private def split_bounds(text : String) : Array(String?)
    bounds = [] of String?
    buffer = IO::Memory.new
    quoted = false
    escaped = false
    present = false
    reader = Char::Reader.new(text)
    while reader.has_next?
      char = reader.current_char
      if escaped
        buffer << char
        escaped = false
        present = true
      elsif char == '\\'
        escaped = true
      elsif char == '"'
        if quoted && reader.peek_next_char == '"'
          buffer << '"'
          reader.next_char
        else
          quoted = !quoted
        end
        present = true
      elsif char == ',' && !quoted
        bounds << bound_text(buffer, present)
        buffer.clear
        present = false
      else
        buffer << char
        present ||= !char.whitespace?
      end
      reader.next_char
    end
    if bounds.size != 1 || quoted || escaped
      raise ArgumentError.new("Invalid PostgreSQL range bounds: #{text}")
    end
    bounds << bound_text(buffer, present)
  end

  # Quoted empty strings are values; only omitted bounds are infinite.
  private def bound_text(buffer : IO::Memory, present : Bool) : String?
    buffer.to_s.strip if present
  end
end
