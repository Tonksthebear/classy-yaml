module Classy
  module Yaml
    class InvalidKeyError < StandardError
      def initialize(data)
        @data = data
      end

      def message
        "yass called with invalid keys: #{@data}. This error can be raised when calling nested keys on an un-nested root."
      end
    end
  end
end
