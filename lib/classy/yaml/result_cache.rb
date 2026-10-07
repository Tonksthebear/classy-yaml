module Classy
  module Yaml
    # A bounded, thread-safe least-recently-used cache of yass results.
    #
    # Entries are indexed by the key's hash, computed once per call, and keep the
    # key itself so a lookup only hits when the keys are eql?. A store carries the
    # generation its result was computed under; a store from an older generation
    # is dropped, so a lookup that raced a reload or a `setup` never caches an
    # answer built from the old YAML.
    class ResultCache
      Entry = Struct.new(:key, :value)

      attr_reader :max_size

      def initialize(max_size)
        @max_size = max_size
        @entries = {}
        @generation = 0
        @lock = Mutex.new
      end

      def generation
        @generation
      end

      def max_size=(value)
        @lock.synchronize do
          @max_size = value
          @entries.shift while @entries.size > @max_size
        end
      end

      def size
        @entries.size
      end

      def get(key, digest = key.hash)
        @lock.synchronize do
          entry = @entries.delete(digest)
          return unless entry

          # Move the entry to the newest end; a colliding key is a miss and its
          # entry is replaced by the next store.
          @entries[digest] = entry
          entry.value if entry.key.eql?(key)
        end
      end

      def store(key, value, generation, digest = key.hash)
        @lock.synchronize do
          return unless generation == @generation && @max_size.positive?

          @entries.delete(digest)
          @entries[digest] = Entry.new(key, value).freeze
          @entries.shift if @entries.size > @max_size
        end
      end

      # Drops every result and invalidates stores already in progress.
      def invalidate
        @lock.synchronize do
          @generation += 1
          @entries.clear
        end
      end
    end
  end
end
