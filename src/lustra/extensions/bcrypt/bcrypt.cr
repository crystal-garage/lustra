module Lustra::Model::Converter::BcryptPasswordConverter
  def self.to_column(x) : ::Crypto::Bcrypt::Password?
    case x
    when String
      ::Crypto::Bcrypt::Password.new(x)
    when ::Crypto::Bcrypt::Password
      x
    when Nil
      nil
    else
      raise Lustra::ErrorMessages.converter_error(x.class.name, "Crypto::Bcrypt::Password")
    end
  end

  def self.to_db(x : ::Crypto::Bcrypt::Password?)
    case x
    when ::Crypto::Bcrypt::Password?
      x.to_s
    when Nil
      nil
    end
  end
end

Lustra::Model::Converter.add_converter("Crypto::Bcrypt::Password", Lustra::Model::Converter::BcryptPasswordConverter)
