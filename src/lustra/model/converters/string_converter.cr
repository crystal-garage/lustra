require "./base"

class Lustra::Model::Converter::StringConverter
  def self.to_column(x) : String?
    case x
    when Nil
      nil
    when Slice(UInt8)
      String.new(x)
    else
      x.to_s
    end
  end

  def self.to_db(x : String?)
    x
  end
end

Lustra::Model::Converter.add_converter("String", Lustra::Model::Converter::StringConverter)
