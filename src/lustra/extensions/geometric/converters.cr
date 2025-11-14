# Converters for PostgreSQL Geometric Types

# Point converter
class Lustra::Model::Converter::PGGeoPointConverter
  def self.to_column(x) : PG::Geo::Point?
    case x
    when PG::Geo::Point
      x
    when String
      # Parse from PostgreSQL point string format: "(x,y)"
      if x =~ /^\((-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)\)$/
        PG::Geo::Point.new($1.to_f64, $2.to_f64)
      else
        raise "Cannot convert string '#{x}' to PG::Geo::Point"
      end
    when Nil
      nil
    else
      raise "Cannot convert from #{x.class} to PG::Geo::Point"
    end
  end

  def self.to_db(x : PG::Geo::Point?)
    case x
    when Nil
      nil
    when PG::Geo::Point
      # Convert to PostgreSQL point format: "(x,y)"
      "(#{x.x},#{x.y})"
    else
      x
    end
  end
end

# Circle converter
class Lustra::Model::Converter::PGGeoCircleConverter
  def self.to_column(x) : PG::Geo::Circle?
    case x
    when PG::Geo::Circle
      x
    when String
      # Parse from PostgreSQL circle string format: "<(x,y),r>"
      if x =~ /^<\((-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)\),(-?\d+(?:\.\d+)?)\>$/
        PG::Geo::Circle.new($1.to_f64, $2.to_f64, $3.to_f64)
      else
        raise "Cannot convert string '#{x}' to PG::Geo::Circle"
      end
    when Nil
      nil
    else
      raise "Cannot convert from #{x.class} to PG::Geo::Circle"
    end
  end

  def self.to_db(x : PG::Geo::Circle?)
    case x
    when Nil
      nil
    when PG::Geo::Circle
      # Convert to PostgreSQL circle format: "<(x,y),r>"
      "<(#{x.x},#{x.y}),#{x.radius}>"
    else
      x
    end
  end
end

# Polygon converter
class Lustra::Model::Converter::PGGeoPolygonConverter
  def self.to_column(x) : PG::Geo::Polygon?
    case x
    when PG::Geo::Polygon
      x
    when String
      # For string parsing, we'd need to implement PostgreSQL polygon string format
      # This is complex, so for now we just handle the direct case
      raise "String to PG::Geo::Polygon conversion not implemented"
    when Nil
      nil
    else
      raise "Cannot convert from #{x.class} to PG::Geo::Polygon"
    end
  end

  def self.to_db(x : PG::Geo::Polygon?)
    case x
    when Nil
      nil
    when PG::Geo::Polygon
      # Convert to PostgreSQL polygon format: "((x1,y1),...,(xn,yn))"
      points = x.points.map { |p| "(#{p.x},#{p.y})" }.join(",")
      "(#{points})"
    else
      x
    end
  end
end

# Box converter
class Lustra::Model::Converter::PGGeoBoxConverter
  def self.to_column(x) : PG::Geo::Box?
    case x
    when PG::Geo::Box
      x
    when String
      # Parse from PostgreSQL box string format: "(x1,y1),(x2,y2)"
      if x =~ /^\((-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)\),\((-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)\)$/
        PG::Geo::Box.new($1.to_f64, $2.to_f64, $3.to_f64, $4.to_f64)
      else
        raise "Cannot convert string '#{x}' to PG::Geo::Box"
      end
    when Nil
      nil
    else
      raise "Cannot convert from #{x.class} to PG::Geo::Box"
    end
  end

  def self.to_db(x : PG::Geo::Box?)
    case x
    when Nil
      nil
    when PG::Geo::Box
      # Convert to PostgreSQL box format: "(x1,y1),(x2,y2)"
      "(#{x.x1},#{x.y1}),(#{x.x2},#{x.y2})"
    else
      x
    end
  end
end

# Line converter
class Lustra::Model::Converter::PGGeoLineConverter
  def self.to_column(x) : PG::Geo::Line?
    case x
    when PG::Geo::Line
      x
    when String
      # Parse from PostgreSQL line string format: "{A,B,C}"
      if x =~ /^\{(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)\}$/
        PG::Geo::Line.new($1.to_f64, $2.to_f64, $3.to_f64)
      else
        raise "Cannot convert string '#{x}' to PG::Geo::Line"
      end
    when Nil
      nil
    else
      raise "Cannot convert from #{x.class} to PG::Geo::Line"
    end
  end

  def self.to_db(x : PG::Geo::Line?)
    case x
    when Nil
      nil
    when PG::Geo::Line
      # Convert to PostgreSQL line format: "{A,B,C}"
      "{#{x.a},#{x.b},#{x.c}}"
    else
      x
    end
  end
end

# Path converter
class Lustra::Model::Converter::PGGeoPathConverter
  def self.to_column(x) : PG::Geo::Path?
    case x
    when PG::Geo::Path
      x
    when String
      # For string parsing, we'd need to implement PostgreSQL path string format
      # This is complex, so for now we just handle the direct case
      raise "String to PG::Geo::Path conversion not implemented"
    when Nil
      nil
    else
      raise "Cannot convert from #{x.class} to PG::Geo::Path"
    end
  end

  def self.to_db(x : PG::Geo::Path?)
    case x
    when Nil
      nil
    when PG::Geo::Path
      # Convert to PostgreSQL path format: "[(x1,y1),...,(xn,yn)]" or "((x1,y1),...,(xn,yn))"
      points = x.points.map { |p| "(#{p.x},#{p.y})" }.join(",")
      if x.closed?
        "((#{points}))"
      else
        "[(#{points})]"
      end
    else
      x
    end
  end
end

# LineSegment converter
class Lustra::Model::Converter::PGGeoLineSegmentConverter
  def self.to_column(x) : PG::Geo::LineSegment?
    case x
    when PG::Geo::LineSegment
      x
    when String
      # Parse from PostgreSQL line segment string format: "[(x1,y1),(x2,y2)]"
      if x =~ /^\[\((-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)\),\((-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)\)\]$/
        PG::Geo::LineSegment.new($1.to_f64, $2.to_f64, $3.to_f64, $4.to_f64)
      else
        raise "Cannot convert string '#{x}' to PG::Geo::LineSegment"
      end
    when Nil
      nil
    else
      raise "Cannot convert from #{x.class} to PG::Geo::LineSegment"
    end
  end

  def self.to_db(x : PG::Geo::LineSegment?)
    case x
    when Nil
      nil
    when PG::Geo::LineSegment
      # Convert to PostgreSQL line segment format: "[(x1,y1),(x2,y2)]"
      "[(#{x.x1},#{x.y1}),(#{x.x2},#{x.y2})]"
    else
      x
    end
  end
end

# Register all the converters with both full and short names
Lustra::Model::Converter.add_converter("PG::Geo::Point", Lustra::Model::Converter::PGGeoPointConverter)
Lustra::Model::Converter.add_converter("Point", Lustra::Model::Converter::PGGeoPointConverter)
Lustra::Model::Converter.add_converter("PG::Geo::Circle", Lustra::Model::Converter::PGGeoCircleConverter)
Lustra::Model::Converter.add_converter("Circle", Lustra::Model::Converter::PGGeoCircleConverter)
Lustra::Model::Converter.add_converter("PG::Geo::Polygon", Lustra::Model::Converter::PGGeoPolygonConverter)
Lustra::Model::Converter.add_converter("Polygon", Lustra::Model::Converter::PGGeoPolygonConverter)
Lustra::Model::Converter.add_converter("PG::Geo::Box", Lustra::Model::Converter::PGGeoBoxConverter)
Lustra::Model::Converter.add_converter("Box", Lustra::Model::Converter::PGGeoBoxConverter)
Lustra::Model::Converter.add_converter("PG::Geo::Line", Lustra::Model::Converter::PGGeoLineConverter)
Lustra::Model::Converter.add_converter("Line", Lustra::Model::Converter::PGGeoLineConverter)
Lustra::Model::Converter.add_converter("PG::Geo::Path", Lustra::Model::Converter::PGGeoPathConverter)
Lustra::Model::Converter.add_converter("Path", Lustra::Model::Converter::PGGeoPathConverter)
Lustra::Model::Converter.add_converter("PG::Geo::LineSegment", Lustra::Model::Converter::PGGeoLineSegmentConverter)
Lustra::Model::Converter.add_converter("LineSegment", Lustra::Model::Converter::PGGeoLineSegmentConverter)
