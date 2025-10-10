module Lustra::Model::HasTimestamps
  # Generate the columns `updated_at` and `created_at`
  # The two column values are automatically set during insertion
  #   or update of the model.
  macro timestamps
    column(updated_at : Time)
    column(created_at : Time)

    before(:validate) do |model|
      model = model.as(self)

      unless model.persisted?
        now = Time.local
        model.created_at = now unless model.created_at_column.defined?
        model.updated_at = now unless model.updated_at_column.defined?
      end
    end

    after(:validate) do |model|
      model = model.as(self)

      # In the case the updated_at has been changed, we do not override.
      # It happens on first insert, in the before validation setup.
      model.updated_at = Time.local if model.changed? && !model.updated_at_column.changed?
    end

    # Updates timestamp columns without triggering validations or callbacks.
    #
    # ```
    # user.touch             # Updates updated_at
    # user.touch(2.days.ago) # Updates updated_at to specific time
    # ```
    def touch(time : Time = Time.local) : Lustra::Model
      raise Lustra::Model::Error.new("Model must be persisted before touching") unless persisted?

      update_columns(updated_at: time)

      self
    end

    # Updates the specified column and updated_at without triggering validations or callbacks.
    #
    # ```
    # user.touch(:last_login_at) # Updates last_login_at and updated_at
    # user.touch(:last_seen_at, 1.hour.ago)
    # ```
    def touch(column : Symbol | String, time : Time = Time.local) : Lustra::Model
      raise Lustra::Model::Error.new("Model must be persisted before touching") unless persisted?

      column_name = column.to_s

      # Update the specified column and updated_at (unless the column is updated_at itself)
      if column_name == "updated_at"
        update_columns(updated_at: time)
      else
        updates = {column_name => time, "updated_at" => time} of String => Lustra::SQL::Any
        update_columns(updates)
      end

      self
    end

    # Updates multiple timestamp columns without triggering validations or callbacks.
    #
    # ```
    # user.touch([:last_login_at, :last_seen_at])
    # user.touch([:last_login_at, :last_seen_at], 3.days.ago)
    # ```
    def touch(columns : Array(Symbol | String), time : Time = Time.local) : Lustra::Model
      raise Lustra::Model::Error.new("Model must be persisted before touching") unless persisted?

      updates = {} of String => Lustra::SQL::Any
      columns.each do |column|
        updates[column.to_s] = time
      end

      # Also update updated_at unless it was explicitly included
      unless columns.any? { |c| c.to_s == "updated_at" }
        updates["updated_at"] = time
      end

      update_columns(updates)

      self
    end

    # Updates multiple timestamp columns at once.
    #
    # ```
    # user.touch(:last_login_at, :last_seen_at)
    # user.touch(:last_login_at, :last_seen_at, time: 1.day.ago)
    # ```
    def touch(*columns, time : Time = Time.local) : Lustra::Model
      touch(columns.to_a, time)
    end
  end
end
