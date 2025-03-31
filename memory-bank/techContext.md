# Tech Context: Classy YAML

## Language & Framework
- Ruby
- Rails (Targeting versions ~> 7.0 and main branch/8.x based on Appraisals)

## Key Dependencies
- `rails`: Core dependency.
- `view_component`: Required for component-specific helper functionality (~> 2.0 for Rails 7, >= 3.0 for Rails 8).
- `sprockets-rails` / `propshaft`: Handled via Rails dependency, relevant for asset pipeline context.
- `psych` (Ruby Standard Library): Used implicitly for YAML parsing.

## Development & Testing
- **Testing Framework:** Minitest
- **Dependency Management:** Bundler (`Gemfile`)
- **Version Matrix Testing:** Appraisal (See `Appraisals` file for specific Rails/dependency combinations tested).
- **Linting/Formatting:** (Please specify if tools like RuboCop are used)

## Build & Distribution
- Standard RubyGems build process (`gem build classy-yaml.gemspec`).
- Published on RubyGems.org.

## Constraints & Considerations
- Performance of YAML parsing and merging, especially with many files or large definitions.
- Ensuring compatibility across supported Rails and ViewComponent versions.
- Thread safety if YAML loading/configuration happens dynamically (though typically done at boot). 