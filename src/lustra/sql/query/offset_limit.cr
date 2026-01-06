module Lustra::SQL::Query::OffsetLimit
  macro included
    getter limit : Int64? = nil
    getter offset : Int64? = nil
  end

  def limit(x : Int32 | Int64?)
    @limit = x ? Int64.new(x) : nil
    change!
  end

  def clear_limit
    @limit = nil
    change!
  end

  def clear_offset
    @offset = nil
    change!
  end

  def offset(x : Int32 | Int64?)
    @offset = x ? Int64.new(x) : nil
    change!
  end

  protected def print_limit_offsets
    [@limit && ("LIMIT #{@limit}"), @offset && "OFFSET #{@offset}"].compact.join(" ")
  end
end
