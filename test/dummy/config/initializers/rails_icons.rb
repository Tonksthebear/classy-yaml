return unless defined?(RailsIcons)

RailsIcons.configure do |config|
  config.default_library = "heroicons"

  config.libraries.merge!(
    heroicons: {
      solid: {
        default: {
          css: ""
        }
      }
    }
  )
end
