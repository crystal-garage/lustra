# The Lustra::Model::QueryCache
# is a __fire-and-forget__ cache used for caching associations and preventing
# the N+1 query anti-pattern.
#
# This is not a global cache: One cache instance exists per collection, and the cache
# disappears when the Collection is unreferenced.
#
# Each cache can reference multiple relations at the same time.
# This cache uses an underlying hash to access reference keys.
class Lustra::Model::QueryCache
  # :nodoc:
  record CacheKey, relation_name : String, relation_value : Lustra::SQL::Any, relation_model : String

  # Store associations through a Hash. For performance reasons, the hash stores
  # model arrays as `Pointer(Nil)` even though the underlying value is an
  # Array(T). This works around a current Crystal limitation where you cannot
  # safely store or cast an `Array(Child)` in an `Array(Parent)` reference while
  # Child inherits from Parent.
  @cache : Hash(CacheKey, Pointer(Nil)) = {} of CacheKey => Pointer(Nil)

  # References the current cached relations.
  @cache_activation : Set(String) = Set(String).new

  def fetch
    query
  end

  # Mark this cache as active for a specific relation name.
  # Returns `self`.
  def active(relation_name)
    @cache_activation.add(relation_name)

    self
  end

  # Check whether the cache is active on a certain association.
  # Returns `true` if `relation_name` is flagged as cached, or `false` otherwise.
  def active?(relation_name)
    @cache_activation.includes?(relation_name)
  end

  # Try to hit the cache. If an array is found, it will be returned.
  # Otherwise, an empty array is returned.
  #
  # This method does not check whether a relation is actively cached. Therefore,
  # hitting a non-cached relation always returns an empty array.
  def hit(relation_name, relation_value, klass : T.class) : Array(T) forall T
    @cache.fetch CacheKey.new(relation_name, relation_value, T.name) do
      [] of T
    end.unsafe_as(Array(T))
  end

  # Set the cached array for a specific key `{relation_name, relation_value}`.
  def set(relation_name, relation_value, arr : Array(T)) forall T
    # We store the array as `Pointer(Nil)` to satisfy the compiler and avoid
    # garbage collection. In `hit`, we cast back to the real Array(T) type to
    # avoid copying the array.
    #
    # See: https://github.com/crystal-lang/crystal/issues/5289
    @cache[CacheKey.new(relation_name, relation_value, T.name)] = arr.unsafe_as(Pointer(Nil))
  end

  # Perform operations with the cache, then clear it.
  def with_cache(&)
    yield
  ensure
    clear
  end

  # Empty the cache and mark all relations as inactive.
  def clear
    @cache.clear
    @cache_activation.clear
  end
end
