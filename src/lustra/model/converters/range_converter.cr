require "./base"
require "../../sql/range_literal"

# Keep PostgreSQL's empty and bound flags; callers can explicitly convert a
# representable value with PG::Range#to_crystal_range when needed.
module Lustra::Model::Converter::RangeConverter(T)
  def self.to_column(value) : PG::Range(T)?
    case value
    when Nil
      nil
    when PG::Range
      return PG::Range(T).empty if value.empty?
      PG::Range(T).new(bound(value.begin), bound(value.end),
        lower_inclusive: value.lower_inclusive, upper_inclusive: value.upper_inclusive)
    when ::Range
      lower = bound(value.begin)
      upper = bound(value.end)
      return PG::Range(T).empty if !lower.nil? && lower == upper && value.excludes_end?
      PG::Range(T).new(lower, upper,
        lower_inclusive: !lower.nil?, upper_inclusive: !upper.nil? && !value.excludes_end?)
    when String
      SQL::RangeLiteral.parse(value, T) { |text| bound(text) }
    else
      raise ArgumentError.new("Cannot convert #{value.class} to PG::Range(#{T})")
    end
  end

  def self.to_db(value : PG::Range(T)?) : String?
    value.try { |range| SQL::RangeLiteral.format(range) }
  end

  private def self.bound(value) : T?
    return if value.nil?
    return value if value.is_a?(T)
    {% if T == Int32 %}
      value.to_s.to_i32
    {% elsif T == Int64 %}
      value.to_s.to_i64
    {% elsif T == BigDecimal %}
      BigDecimal.new(value.to_s)
    {% elsif T == PG::Numeric %}
      numeric(value.to_s)
    {% elsif T == Time %}
      text = value.to_s
      return Time.parse_utc(text, "%F") if text.size == 10
      text = text.sub(' ', 'T')
      if zone = text.index('+', 10) || text.index('-', 10)
        text += ":00" if text.size - zone == 3
      elsif !text.ends_with?('Z') && !text.ends_with?('z')
        text += 'Z'
      end
      Time.parse_iso8601(text)
    {% else %}
      {% raise "Unsupported range bound type: #{T}" %}
    {% end %}
  end

  # PG::Numeric exposes a binary-value constructor. Build its base-10000 digits
  # from BigDecimal's exact coefficient and scale, without passing through Float.
  private def self.numeric(text : String) : PG::Numeric
    if text == "NaN"
      return PG::Numeric.new(0_i16, 0_i16, PG::Numeric::Sign::Nan.value, 0_i16, [] of Int16)
    end
    decimal = BigDecimal.new(text)
    scale = decimal.scale.to_i
    padding = (4 - scale % 4) % 4
    coefficient = decimal.value.abs * BigInt.new(10) ** padding
    digits = [] of Int16
    until coefficient.zero?
      digits << (coefficient % 10_000).to_i16
      coefficient //= 10_000
    end
    digits.reverse!
    weight = digits.empty? ? 0 : digits.size - 1 - (scale + padding) // 4
    while digits.last? == 0
      digits.pop
    end
    sign = decimal.value < 0 ? PG::Numeric::Sign::Neg : PG::Numeric::Sign::Pos
    PG::Numeric.new(digits.size.to_i16, weight.to_i16, sign.value, scale.to_i16, digits)
  end
end

module Lustra::Model::Converter
  add_converter("PG::Range(Int32)", Lustra::Model::Converter::RangeConverter(Int32))
  add_converter("PG::Range(Int64)", Lustra::Model::Converter::RangeConverter(Int64))
  add_converter("PG::Range(Time)", Lustra::Model::Converter::RangeConverter(Time))
  add_converter("PG::Range(PG::Numeric)", Lustra::Model::Converter::RangeConverter(PG::Numeric))
  add_converter("PG::Range(BigDecimal)", Lustra::Model::Converter::RangeConverter(BigDecimal))
end
