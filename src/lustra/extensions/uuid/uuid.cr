struct UUID
  def to_json(json : JSON::Builder)
    json.string(to_s)
  end
end

# Convert from UUID column to Crystal's UUID
class Lustra::Model::Converter::UUIDConverter
  def self.to_column(x) : UUID?
    case x
    when String
      UUID.new(x)
    when Slice(UInt8)
      UUID.new(x)
    when UUID
      x
    when Nil
      nil
    else
      raise Lustra::ErrorMessages.converter_error(x.class.name, "UUID")
    end
  end

  def self.to_db(x : UUID?)
    if x.nil?
      nil
    else
      x.to_s
    end
  end
end

Lustra::Model::Converter.add_converter("UUID", Lustra::Model::Converter::UUIDConverter)

Lustra::Model::HasSerialPkey.add_pkey_type "uuid" do
  column __name__ : UUID, primary: true, presence: true

  before(:validate) do |m|
    if !m.persisted? && m.as(self).__name___column.value(nil).nil?
      m.as(self).__name__ = UUID.random
    end
  end
end
