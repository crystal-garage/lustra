struct Time
  def +(interval : Lustra::Interval)
    [
      interval.months.months,
      interval.days.days,
      interval.hours.hours,
      interval.minutes.minutes,
      interval.seconds.seconds,
      interval.milliseconds.milliseconds,
      interval.microseconds.microseconds,
    ].reduce(self) { |acc, e| acc + e }
  end

  def -(interval : Lustra::Interval)
    [
      interval.months.months,
      interval.days.days,
      interval.hours.hours,
      interval.minutes.minutes,
      interval.seconds.seconds,
      interval.milliseconds.milliseconds,
      interval.microseconds.microseconds,
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
