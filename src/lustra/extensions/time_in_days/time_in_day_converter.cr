struct Time
  def at(time_in_day : Lustra::TimeInDay, timezone = nil) : Time
    if timezone
      if timezone.is_a?(String)
        timezone = Time::Location.load(timezone)
      end

      self.in(timezone).at_beginning_of_day + time_in_day.microseconds.microseconds
    else
      at_beginning_of_day + time_in_day.microseconds.microseconds
    end
  end

  def +(time_in_day : Lustra::TimeInDay)
    self + time_in_day.microseconds.microseconds
  end

  def -(time_in_day : Lustra::TimeInDay)
    self - time_in_day.microseconds.microseconds
  end
end

module Lustra::TimeInDay::Converter
  def self.to_column(x) : TimeInDay?
    case x
    when TimeInDay
      x
    when UInt64
      TimeInDay.new(x)
    when Slice
      mem = IO::Memory.new(x, writeable: false)
      TimeInDay.new(mem.read_bytes(UInt64, IO::ByteFormat::BigEndian))
    when String
      TimeInDay.parse(x)
    when Nil
      nil
    else
      raise "Cannot convert to TimeInDay from #{x.class}"
    end
  end

  def self.to_db(x : TimeInDay?)
    x ? x.to_s : nil
  end
end

Lustra::Model::Converter.add_converter("Lustra::TimeInDay", Lustra::TimeInDay::Converter)
