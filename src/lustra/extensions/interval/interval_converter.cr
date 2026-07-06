struct Time
  def +(other : Lustra::Interval)
    [
      other.months.months,
      other.days.days,
      other.hours.hours,
      other.minutes.minutes,
      other.seconds.seconds,
      other.milliseconds.milliseconds,
      other.microseconds.microseconds,
    ].reduce(self) { |acc, e| acc + e }
  end

  def -(other : Lustra::Interval)
    [
      other.months.months,
      other.days.days,
      other.hours.hours,
      other.minutes.minutes,
      other.seconds.seconds,
      other.milliseconds.milliseconds,
      other.microseconds.microseconds,
    ].reduce(self) { |acc, e| acc - e }
  end
end

class Lustra::Interval::Converter
  def self.to_column(x) : Lustra::Interval?
    case x
    when PG::Interval
      Lustra::Interval.new(x.months, x.days, x.microseconds)
    when Slice(UInt8)
      Lustra::Interval.decode(x.as(Slice(UInt8)))
    when Lustra::Interval
      x
    when Nil
      nil
    else
      raise Lustra::ErrorMessages.converter_error(x.class, "Interval")
    end
  end

  def self.to_db(x : Lustra::Interval?)
    x.try &.to_sql
  end
end

Lustra::Model::Converter.add_converter("Lustra::Interval", Lustra::Interval::Converter)
