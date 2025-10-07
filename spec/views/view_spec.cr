require "../spec_helper"

module ViewSpec
  describe "Lustra::View" do
    it "recreate the views on migration" do
      temporary do
        Lustra::View.register :room_per_days do |view|
          view.require(:rooms, :year_days)

          view.query <<-SQL
            SELECT room_id, day
            FROM year_days
            CROSS JOIN rooms
            SQL
        end

        Lustra::View.register :rooms do |view|
          view.query <<-SQL
            SELECT room.id AS room_id
            FROM generate_series(1, 4) AS room(id)
            SQL
        end

        Lustra::View.register :year_days do |view|
          view.query <<-SQL
            SELECT date.day::date AS day
            FROM   generate_series(
              date_trunc('day', NOW()),
              date_trunc('day', NOW() + INTERVAL '364 days'),
              INTERVAL '1 day'
            ) AS date(day)
            SQL
        end

        Lustra::Migration::Manager.instance.reinit!
        Lustra::Migration::Manager.instance.apply_all

        # Ensure than the view is loaded and working properly
        Lustra::SQL.select.from("room_per_days").agg("COUNT(day)", Int64).should eq(4*365)
        Lustra::View.clear
      end
    end
  end
end
