module Lustra::SQL::Query::WithPagination
  DEFAULT_LIMIT = 50
  DEFAULT_PAGE  =  1

  macro included
    property total_entries : Int64? = nil
  end

  # Enter pagination mode.
  # This is helpful to manage paginated table.
  # Pagination will handle the page progression automatically and update
  # `offset` and `limit` parameters by his own.
  # Page sizes must be positive; page numbers below one use the first page.
  #
  # ```
  # page = query.paginate(2, 50)
  # ```
  def paginate(page : Int32 = DEFAULT_PAGE, per_page : Int32 = DEFAULT_LIMIT)
    raise ArgumentError.new("Page size must be positive") unless per_page > 0

    clear_limit.clear_offset
    @total_entries = count

    page = {1, page}.max
    @limit = per_page.to_i64
    @offset = per_page.to_i64 * (page - 1)
    change!
  end

  # Return the number of items maximum per page.
  def per_page : Int32 | Int64
    limit || DEFAULT_LIMIT
  end

  # Return the current page
  def current_page : Int32 | Int64
    if offset.nil? || limit.nil?
      DEFAULT_PAGE
    else
      offset.as(Int64) // limit.as(Int64) + 1
    end
  end

  # Return the total number of pages.
  def total_pages : Int32 | Int64
    if limit.nil? || total_entries.nil?
      1
    else
      pages, remainder = total_entries.as(Int64).divmod(limit.as(Int64))
      pages + (remainder > 0 ? 1 : 0)
    end
  end

  # Return `current_page - 1` or `nil` if there is no previous page
  def previous_page
    current_page > 1 ? (current_page - 1) : nil
  end

  # Return `current_page + 1` or `nil` if there is no next page
  def next_page
    current_page < total_pages ? (current_page + 1) : nil
  end

  def last_page?
    next_page.nil?
  end

  def first_page?
    current_page <= 1
  end

  # Helper method that is true when someone tries to fetch a page with a
  # larger number than the last page. Can be used in combination with flashes
  # and redirecting.
  def out_of_bounds?
    current_page > total_pages
  end
end
