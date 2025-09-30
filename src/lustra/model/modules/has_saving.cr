# This module handles saving models to the database and triggers lifecycle callbacks.
# It's where the actual `:create`, `:update`, `:delete`, and `:save` callbacks are triggered.
#
# Key callback trigger points:
# - `:save` callbacks: triggered for the entire save operation (wraps create/update)
# - `:create` callbacks: triggered when a new record is inserted into the database
# - `:update` callbacks: triggered when an existing record is updated in the database
# - `:delete` callbacks: triggered when a record is deleted from the database
#
# The callbacks are triggered via `with_triggers` which calls `Lustra::Model::EventManager`
module Lustra::Model::HasSaving
  # Default class-wise read_only? method is `false`
  macro included # When included into Model
    macro included # When included into final Model
      class_property? read_only : Bool = false

      # Import a bulk of models in one SQL insert query.
      # Each model must be non-persisted.
      #
      # `on_conflict` callback can be optionnaly turned on
      # to manage constraints of the database.
      #
      # Note: Old models are not modified. This method return a copy of the
      # models as saved in the database.
      #
      # ## Example:
      #
      # ```
      # users = [User.new(id: 1), User.new(id: 2), User.new(id: 3)]
      # users = User.import(users)
      # ```
      def self.import(array : Enumerable(self), on_conflict : (Lustra::SQL::InsertQuery ->)? = nil)
        array.each do |item|
          raise "One of your model is persisted while calling import" if item.persisted?
        end

        hashes = array.map do |item|
          item.trigger_before_events(:save)
          raise "import: Validation failed for `#{item}`" unless item.valid?
          item.trigger_before_events(:create)
          item.to_h
        end

        query = Lustra::SQL.insert_into(self.table, hashes).returning("*")
        on_conflict.call(query) if on_conflict

        o = [] of self
        query.fetch(@@connection) do |hash|
          o << Lustra::Model::Factory.build(self.name, hash, persisted: true,
            fetch_columns: false, cache: nil).as(self)
        end

        o.each(&.trigger_after_events(:create))
        o.each(&.trigger_after_events(:save))

        o
      end
    end
  end

  getter? persisted : Bool

  # Save the model. If the model is already persisted, will call `UPDATE` query.
  # If the model is not persisted, will call `INSERT`
  #
  # Optionally, you can pass a `Proc` to refine the `INSERT` with on conflict
  # resolution functions.
  #
  # Return `false` if the model cannot be saved (validation issue)
  # Return `true` if the model has been correctly saved.
  #
  # Example:
  #
  # ```
  # u = User.new
  # if u.save
  #   puts "User correctly saved !"
  # else
  #   puts "There was a problem during save: "
  #   # do something with `u.errors`
  # end
  # ```
  #
  # ## `on_conflict` optional parameter
  #
  # Example:
  #
  # ```
  # u = User.new id: 123, email: "email@example.com"
  # u.save(-> (qry) { qry.on_conflict.do_update { |u| u.set(email: "email@example.com") } #update
  # # IMPORTANT NOTICE: user may not be saved, but will be still detected as persisted !
  # ```
  #
  # You may want to use a block for `on_conflict` optional parameter:
  #
  # ```
  # u = User.new id: 123, email: "email@example.com"
  # u.save do |qry|
  #    qry.on_conflict.do_update { |u| u.set(email: "email@example.com")
  # end
  # ```
  #
  def save(on_conflict : (Lustra::SQL::InsertQuery ->)? = nil)
    return false if self.class.read_only?

    with_triggers(:save) do
      if valid?
        if persisted?
          h = update_h
          unless h.empty?
            with_triggers(:update) do
              save_main_model(on_conflict)
            end
          end
        else
          with_triggers(:create) do
            save_main_model(on_conflict)
          end
        end

        clear_change_flags

        return true
      else
        return false
      end
    end
  end

  def save(&block)
    save(on_conflict: block)
  end

  # Performs `save` call, but instead of returning `false` if validation failed,
  # raise `Lustra::Model::InvalidError` exception
  # Automatically handles built associations
  def save!(on_conflict : (Lustra::SQL::InsertQuery ->)? = nil)
    raise Lustra::Model::ReadOnlyError.new(self) if self.class.read_only?

    if has_built_associations?
      raise Lustra::Model::InvalidError.new(self) unless save_with_associations(on_conflict)
    else
      raise Lustra::Model::InvalidError.new(self) unless save(on_conflict)
    end

    self
  end

  # Pass the `on_conflict` optional parameter via block.
  def save!(&block : Lustra::SQL::InsertQuery ->)
    save!(block)
  end

  # Save the model along with all built associations
  def save_with_associations(on_conflict : (Lustra::SQL::InsertQuery ->)? = nil)
    return false if self.class.read_only?

    with_triggers(:save) do
      if valid?
        save_built_associations

        if persisted?
          h = update_h
          unless h.empty?
            with_triggers(:update) do
              save_main_model(on_conflict)
            end
          end
        else
          with_triggers(:create) do
            save_main_model(on_conflict)
          end
        end

        handle_through_associations

        clear_change_flags
        clear_built_associations

        return true
      else
        return false
      end
    end
  end

  # Set the fields passed as argument and call `save` on the object
  def update(**args)
    set(**args)
    save
  end

  # Set the fields passed as argument and call `save!` on the object
  def update!(**args)
    set(**args)
    save!
  end

  # :nodoc:
  def update(named_tuple : NamedTuple)
    set(named_tuple)
    save
  end

  # :nodoc:
  def update!(named_tuple : NamedTuple)
    set(named_tuple)
    save!
  end

  def reload : self
    set(self.class.query.where { var("#{self.class.__pkey__}") == __pkey__ }.fetch_first!)

    invalidate_caching

    @attributes.clear
    clear_change_flags
    @persisted = true

    self
  end

  # Delete the model by building and executing a `DELETE` query.
  # A deleted model is not persisted anymore, and can be saved again.
  # Lustra will do `INSERT` instead of `UPDATE` then
  # Return `true` if the model has been successfully deleted, and `false` otherwise.
  def delete
    return false unless persisted?

    with_triggers(:delete) do
      Lustra::SQL::DeleteQuery.new.from(self.class.full_table_name).where { var("#{self.class.__pkey__}") == __pkey__ }.execute(@@connection)

      @persisted = false
      clear_change_flags
    end

    true
  end

  private def save_built_associations
    built_associations.each do |_, models|
      models.each do |model|
        model.save! unless model.persisted?
      end
    end
  end

  private def save_main_model(on_conflict : (Lustra::SQL::InsertQuery ->)? = nil)
    if persisted?
      h = update_h

      unless h.empty?
        Lustra::SQL.update(self.class.full_table_name).set(update_h).where { var("#{self.class.__pkey__}") == __pkey__ }.execute(@@connection)
      end
    else
      query = Lustra::SQL.insert_into(self.class.full_table_name, to_h).returning("*")
      on_conflict.call(query) if on_conflict
      hash = query.execute(@@connection)

      reset(hash)
      @persisted = true
    end
  end

  private def handle_through_associations
    # Handle has_many through relationships after main model is saved
    # This avoids recursion because the main model is already persisted
    built_associations.each do |association_name, models|
      # Call the trigger method on the parent model (self) with the built models
      if self.responds_to?(:__trigger_append_operation_for_association__)
        self.__trigger_append_operation_for_association__(association_name, models)
      end
    end
  end
end
