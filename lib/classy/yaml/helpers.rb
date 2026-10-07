module Classy
  module Yaml
    module Helpers
      # Fetches utility classes from YAML files based on the provided keys.
      # The method follows a priority order:
      # 1. Component files (highest priority)
      # 2. Extra files
      # 3. Default YAML
      # 4. Engine files (lowest priority)
      #
      # @param args [Array] Array of keys to look up in the YAML files
      # @return [String] Space-separated list of CSS classes
      def yass(*args)
        Classy::Yaml.classes_for(args, tailwind_merge_available?)
      end

      private

      # Checks if tailwind_merge gem is available
      # @return [Boolean] True if tailwind_merge is available
      def tailwind_merge_available?
        return @tailwind_merge_available if defined?(@tailwind_merge_available)

        Classy::Yaml.tailwind_merge_available?
      end
    end
  end
end
