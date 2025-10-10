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

    # Saves the record with the updated_at set to the current time.
    # Does not bypass validations or callbacks.
    #
    # ```
    # user.touch             # Updates updated_at
    # user.touch(2.days.ago) # Updates updated_at to specific time
    # ```
    def touch(time : Time = Time.local) : Lustra::Model
      self.updated_at = time
      self.save!

      self
    end

    # Updates the specified column and updated_at to the current time.
    # Does not bypass validations or callbacks.
    #
    # ```
    # user.touch(:last_login_at) # Updates last_login_at and updated_at
    # user.touch(:last_seen_at, 1.hour.ago)
    # ```
    def touch(column : Symbol | String, time : Time = Time.local) : Lustra::Model
      column_name = column.to_s

      # Use set to update the column value
      set({column_name => time})

      # Also update updated_at unless it's the column being touched
      self.updated_at = time unless column_name == "updated_at"

      self.save!

      self
    end

    # Updates the specified columns and updated_at to the current time.
    # Does not bypass validations or callbacks.
    #
    # ```
    # user.touch([:last_login_at, :last_seen_at])
    # user.touch([:last_login_at, :last_seen_at], 3.days.ago)
    # ```
    def touch(columns : Array(Symbol | String), time : Time = Time.local) : Lustra::Model
      # Update each specified column
      updates = {} of String => Lustra::SQL::Any
      columns.each do |column|
        updates[column.to_s] = time
      end

      set(updates)

      # Also update updated_at unless it was explicitly included
      unless columns.any? { |c| c.to_s == "updated_at" }
        self.updated_at = time
      end

      self.save!

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
