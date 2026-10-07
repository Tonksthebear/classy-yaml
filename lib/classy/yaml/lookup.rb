module Classy
  module Yaml
    # Turns yass arguments into classes. The YAML layers are compiled once at load
    # (see Classy::Yaml.compile), so a lookup only walks frozen hashes and arrays.
    module Lookup
      EMPTY = [].freeze
      # Returned by walk when a key path goes through a value that is not a hash.
      INVALID = Object.new.freeze
      # Cache key markers. Hash order changes the output, so a key lists hash
      # entries in order instead of using Hash#eql?, which ignores order.
      HASH_START = Object.new.freeze
      ARRAY_START = Object.new.freeze
      CLOSE = Object.new.freeze

      module_function

      # Returns an order-sensitive cache key for the arguments, or nil when an
      # argument is not a plain value (its #to_s could change between calls).
      def cache_key(args, tailwind)
        key = [ tailwind ]
        append_key(args, key) ? key : nil
      end

      def append_key(value, key)
        case value
        when Symbol, String, Integer, Float, Pathname, nil, true, false
          key << value
        when Array
          key << ARRAY_START
          value.each { |child| return false unless append_key(child, key) }
          key << CLOSE
        when Hash
          key << HASH_START
          value.each { |name, child| return false unless append_key(name, key) && append_key(child, key) }
          key << CLOSE
        else
          return false
        end
        true
      end

      # Freezes a cache key built by cache_key. Unfrozen strings are replaced by
      # frozen copies, so a caller that later mutates its strings cannot change it.
      def freeze_key(key)
        key.each_with_index do |part, index|
          key[index] = part.dup.freeze if part.is_a?(String) && !part.frozen?
        end
        key.freeze
      end

      # Collects the lookup key paths and add: values in the order 1.7.2 used:
      # leaf paths first, then the parent paths of each list of values.
      def collect_list(values, root, keys, adds)
        parents = nil
        values.each { |value| parents = collect(value, root, keys, adds, parents) }
        keys.concat(parents) if parents
      end

      def collect(value, root, keys, adds, parents)
        case value
        when Hash
          adds << value[:add] if value.key?(:add)
          value.each do |name, child|
            next if name == :add
            next if root.empty? && (name == :skip_base || name == :classy_files)

            path = [ *root, segment(name) ]
            (parents ||= []) << path
            nested = collect(child, path, keys, adds, nil)
            keys.concat(nested) if nested
          end
        when Array
          collect_list(value, root, keys, adds)
        else
          keys << [ *root, segment(value) ]
        end
        parents
      end

      def segment(value)
        value.is_a?(Symbol) ? value.name : value.to_s
      end

      # Resolves each key path against the layers (lowest priority first) and
      # appends base and specific classes. Returns false when a path went through
      # a value that is not a hash; that call logged a warning.
      def resolve(keys, layers, skip_base, classes)
        clean = true
        skip_base = skip_base == true
        keys.each do |path|
          clean = false unless resolve_path(path, layers, skip_base, classes)
        end
        clean
      end

      def resolve_path(path, layers, skip_base, classes)
        clean = true
        base_classes = nil
        fetched_classes = nil
        last = path.size - 1
        index = layers.size - 1
        while index >= 0
          layer = layers[index]
          index -= 1
          parent = walk(layer, path, last)
          value = case parent
          when Hash then parent[path[last]]
          when nil then nil
          else INVALID
          end

          if value.equal?(INVALID)
            clean = false
            Rails.logger.warn(Classy::Yaml::InvalidKeyError.new(data: path))
          else
            unless skip_base || base_classes
              base_value = if value.is_a?(Hash)
                value["base"]
              elsif last.positive? && parent.is_a?(Hash)
                parent["base"]
              end
              base_classes = classes_of(base_value)
            end
            fetched_classes = classes_of(value) unless fetched_classes || value.is_a?(Hash)
          end

          break if fetched_classes && (skip_base || base_classes)
        end

        classes.concat(base_classes) if base_classes
        classes.concat(fetched_classes) if fetched_classes
        clean
      end

      # Follows path[0...depth] from node. Returns nil when a key is missing, and
      # INVALID when the path continues through a value that is not a hash.
      def walk(node, path, depth)
        index = 0
        while index < depth
          case node
          when Hash then node = node[path[index]]
          when nil then return nil
          else return INVALID
          end
          index += 1
        end
        node
      end

      # A compiled leaf is a frozen array of classes; anything else has none.
      def classes_of(value)
        value if value.is_a?(Array) && !value.empty?
      end
    end
  end
end
