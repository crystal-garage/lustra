require "../../spec_helper"

module PaginationSpec
  describe Lustra::SQL::Query::WithPagination do
    context "page predicates" do
      it "reports an unpaginated query as both the first and last page" do
        query = Lustra::SQL.select("1 AS value")

        query.first_page?.should be_true
        query.last_page?.should be_true
      end

      {
        {"first page of multiple pages", 25_i64, 0, true, false},
        {"middle page", 25_i64, 10, false, false},
        {"partially filled last page", 25_i64, 20, false, true},
        {"full last page", 30_i64, 20, false, true},
        {"single page", 10_i64, 0, true, true},
        {"empty results", 0_i64, 0, true, true},
        {"page beyond the last page", 25_i64, 30, false, true},
      }.each do |description, total, offset, first, last|
        it "identifies the #{description}" do
          query = Lustra::SQL.select("1 AS value").limit(10).offset(offset)
          query.total_entries = total

          query.first_page?.should eq(first)
          query.last_page?.should eq(last)
        end
      end
    end

    context "input boundaries" do
      {0, -1}.each do |size|
        it "rejects page size #{size} without changing the query" do
          query = Lustra::SQL.select("1 AS value").limit(10).offset(20)
          query.total_entries = 100_i64
          original_sql = query.to_sql

          expect_raises(ArgumentError, /positive/) { query.paginate(2, size) }

          query.to_sql.should eq(original_sql)
          query.total_entries.should eq(100_i64)
        end
      end

      it "computes offsets beyond Int32 without overflowing" do
        query = Lustra::SQL.select("1 AS value").paginate(100_000_000, 50)

        query.offset.should eq(4_999_999_950_i64)
        query.limit.should eq(50_i64)
        query.current_page.should eq(100_000_000)
      end

      it "supports the largest Int32 page and size without offset overflow" do
        query = Lustra::SQL.select("1 AS value").paginate(Int32::MAX, Int32::MAX)

        query.offset.should eq(Int32::MAX.to_i64 * (Int32::MAX.to_i64 - 1))
        query.current_page.should eq(Int32::MAX)
      end

      it "reports page counts beyond Int32" do
        query = Lustra::SQL.select("1 AS value").limit(1).offset(0)
        query.total_entries = 3_000_000_000_i64

        query.total_pages.should eq(3_000_000_000_i64)
        query.next_page.should eq(2)
      end

      it "rounds page counts exactly without overflowing at Int64 boundaries" do
        query = Lustra::SQL.select("1 AS value").limit(2)
        query.total_entries = Int64::MAX

        query.total_pages.should eq(4_611_686_018_427_387_904_i64)
        query.limit(1)
        query.total_pages.should eq(Int64::MAX)
      end

      it "keeps current pages and page sizes set through Int64 query limits" do
        query = Lustra::SQL.select("1 AS value").limit(1).offset(3_000_000_000_i64)
        query.current_page.should eq(3_000_000_001_i64)

        query.limit(3_000_000_000_i64)
        query.per_page.should eq(3_000_000_000_i64)
      end

      it "keeps clamping nonpositive page numbers to the first page" do
        {0, -1, Int32::MIN}.each do |page|
          query = Lustra::SQL.select("1 AS value").paginate(page, 10)

          query.offset.should eq(0_i64)
          query.current_page.should eq(1)
          query.previous_page.should be_nil
          query.first_page?.should be_true
          query.last_page?.should be_true
        end
      end
    end

    context "when there's 1901902 records and limit of 25" do
      it "sets the per_page to 25" do
        r = Lustra::SQL.select.from(:users).offset(0).limit(25)
        r.total_entries = 1_901_902_i64
        r.per_page.should eq 25
      end

      it "returns 1 for current_page with no limit set" do
        r = Lustra::SQL.select.from(:users)
        r.total_entries = 1_901_902_i64
        r.current_page.should eq 1
      end

      it "returns 5 for current_page when offset is 100" do
        r = Lustra::SQL.select.from(:users).offset(100).limit(25)
        r.total_entries = 1_901_902_i64
        r.current_page.should eq 5
      end

      it "returns 1 for total_pages when there's no limit" do
        r = Lustra::SQL.select.from(:users)
        r.total_entries = 1_901_902_i64
        r.total_pages.should eq 1
      end

      it "returns 76077 total_pages when 25 per_page" do
        r = Lustra::SQL.select.from(:users).offset(100).limit(25)
        r.total_entries = 1_901_902_i64
        r.total_pages.should eq 76_077
      end

      it "returns 4 as previous_page when on page 5" do
        r = Lustra::SQL.select.from(:users).offset(100).limit(25)
        r.total_entries = 1_901_902_i64
        r.current_page.should eq 5
        r.previous_page.should eq 4
      end

      it "returns nil for previous_page when on page 1" do
        r = Lustra::SQL.select.from(:users).offset(0).limit(25)
        r.total_entries = 1_901_902_i64
        r.current_page.should eq 1
        r.previous_page.should be_nil
      end

      it "returns 6 as next_page when on page 5" do
        r = Lustra::SQL.select.from(:users).offset(100).limit(25)
        r.total_entries = 1_901_902_i64
        r.current_page.should eq 5
        r.next_page.should eq 6
      end

      it "returns nil for next_page when on page 76077" do
        r = Lustra::SQL.select.from(:users).offset(1_901_900).limit(25)
        r.total_entries = 1_901_902_i64
        r.current_page.should eq 76_077
        r.next_page.should be_nil
      end

      it "returns true for out_of_bounds? when current_page is 76078" do
        r = Lustra::SQL.select.from(:users).offset(1_901_925).limit(25)
        r.total_entries = 1_901_902_i64
        r.current_page.should eq 76_078
        r.out_of_bounds?.should be_true
      end

      it "returns false for out_of_bounds? when current_page is in normal range" do
        r = Lustra::SQL.select.from(:users).offset(925).limit(25)
        r.total_entries = 1_901_902_i64
        r.out_of_bounds?.should be_false
      end
    end
  end
end
