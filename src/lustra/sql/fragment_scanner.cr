# :nodoc:
# Scan SQL fragments without splitting inside quoted text, comments, or groups.
# This supports query rewriting; it does not parse or validate complete SQL.
module Lustra::SQL::FragmentScanner
  extend self

  def split_expressions(expression : String) : Array(String)
    items = [] of String
    reader = Char::Reader.new(expression)
    start = 0
    while reader.has_next?
      skipped = skip_fragment(reader)
      if skipped.pos != reader.pos
        reader = skipped
        next
      end
      if reader.current_char == ','
        items << expression.byte_slice(start, reader.pos - start).strip
        start = reader.pos + 1
      end
      reader.next_char
    end
    items << expression.byte_slice(start, expression.bytesize - start).strip
    items
  end

  def identifier_char?(char : Char) : Bool
    !char.ascii? || char.ascii_alphanumeric? || {'_', '$'}.includes?(char)
  end

  def skip_trivia(reader : Char::Reader) : Char::Reader
    while reader.has_next?
      if reader.current_char.whitespace?
        reader.next_char
      elsif {'-', '/'}.includes?(reader.current_char)
        skipped = skip_fragment(reader)
        break if skipped.pos == reader.pos
        reader = skipped
      else
        break
      end
    end

    reader
  end

  def skip_fragment(reader : Char::Reader) : Char::Reader
    case reader.current_char
    when '\'', '"'
      reader = skip_quote(reader)
    when '(', '['
      reader = skip_group(reader)
    when '$'
      if ending = dollar_quote_end(reader)
        reader.pos = ending
      end
    when '-'
      if reader.peek_next_char == '-'
        while reader.has_next? && !{'\n', '\r'}.includes?(reader.current_char)
          reader.next_char
        end
      end
    when '/'
      reader = skip_comment(reader) if reader.peek_next_char == '*'
    end

    reader
  end

  private def skip_group(reader : Char::Reader) : Char::Reader
    closing = reader.current_char == '(' ? ')' : ']'

    reader.next_char

    while reader.has_next? && reader.current_char != closing
      skipped = skip_fragment(reader)

      if skipped.pos != reader.pos
        reader = skipped
      else
        reader.next_char
      end
    end

    reader.next_char if reader.has_next?

    reader
  end

  def skip_quote(reader : Char::Reader) : Char::Reader
    quote = reader.current_char

    escape = quote == '\'' && reader.pos > 0 && {'E'.ord, 'e'.ord}.includes?(reader.string.byte_at(reader.pos - 1))

    reader.next_char

    while reader.has_next?
      if escape && reader.current_char == '\\'
        reader.next_char
        reader.next_char if reader.has_next?
      elsif reader.current_char == quote
        reader.next_char

        break unless reader.current_char == quote

        reader.next_char
      else
        reader.next_char
      end
    end

    reader
  end

  private def dollar_quote_end(reader : Char::Reader) : Int32?
    start = reader.pos

    reader.next_char

    while reader.has_next? && reader.current_char != '$' && identifier_char?(reader.current_char)
      reader.next_char
    end

    return unless reader.current_char == '$'

    delimiter = reader.string.byte_slice(start, reader.pos - start + 1)

    reader.string.byte_index(delimiter, reader.pos + 1).try { |ending| ending + delimiter.bytesize }
  end

  private def skip_comment(reader : Char::Reader) : Char::Reader
    reader.pos += 2

    depth = 1

    while reader.has_next?
      if reader.current_char == '/' && reader.peek_next_char == '*'
        depth += 1
        reader.pos += 2
      elsif reader.current_char == '*' && reader.peek_next_char == '/'
        depth -= 1
        reader.pos += 2

        break if depth == 0
      else
        reader.next_char
      end
    end

    reader
  end
end
