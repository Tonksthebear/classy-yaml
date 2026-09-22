# Classy::Yaml
This was created to provide convenient utility class grouping for environments without a bundler (or any situation where you might not want to add custom css classes). 

## Usage
After installing the gem, the helper method `yass` will be available from anywhere. It looks for the definitions in the YAML file `config/utility_classes.yml` (note: you must add this yourself).

## Installation

Add this line to your application's Gemfile:

```ruby
gem "classy-yaml"
```

And then execute:
```bash
$ bundle install
```

Or install it yourself as:
```bash
$ gem install classy-yaml
```

## Usage

### Default Settings

You can override any of the following settings in an initializer such as `config/initializers/classy_yaml.rb`:

```ruby
Classy::Yaml.setup do |config|
  config.default_file = "config/utility_classes.yml"
  config.extra_files = []
  config.override_tag_helpers = false  # Process all ERB tag helper class: attribute through `yass` when it is a non-string
end
```

### YAML Configuration

Create your utility classes YAML file (`config/utility_classes.yml`):

```yaml
btn:
  base: "px-4 py-2 rounded font-medium" # Base class is automatically applied when referencing a sibling of base
  primary: "bg-blue-500 text-white hover:bg-blue-600"
  secondary: "bg-gray-200 text-gray-800 hover:bg-gray-300"
  danger: "bg-red-500 text-white hover:bg-red-600"

card:
  compact: "m-4"
```

You can also define classes as YAML arrays

```yaml
btn:
  base: "px-4 py-2 rounded font-medium" # Base class is automatically applied when referencing a sibling of base
  primary: "bg-blue-500 text-white hover:bg-blue-600"
  secondary: "bg-gray-200 text-gray-800 hover:bg-gray-300"
  danger: "bg-red-500 text-white hover:bg-red-600"
  warning: # Hideous example
    - "bg-yellow-200"
    - "text-gray-100"
```

> [!WARNING]
> If using tailwind, be sure to point the tailwind configuration to your yaml files for parsing 

### Using the Helper

In your views or components:

```erb
<!-- Basic usage -->
<button class="<%= yass(btn: :primary) %>">
  Click me
</button>

<!-- <button class="px-4 py-2 rounded font-medium bg-blue-500 text-white hover:bg-blue-600">Click me</button> -->

<!-- Multiple classes -->
<button class="<%= yass(btn: :primary, card: :compact) %>">
  Button in card
</button>

<!-- <button class="px-4 py-2 rounded font-medium bg-blue-500 text-white hover:bg-blue-600 m-4">Click me</button> -->

<!-- Skip base classes -->
<button class="<%= yass(btn: :primary, skip_base: true) %>">
  Button without base
</button>

<!-- <button class="bg-blue-500 text-white hover:bg-blue-600">Click me</button> -->

<!-- With config.override_tag_helpers = true -->
<%= tag.div class: { btn: :primary, card: :compact } do %>
  Automatic class processing
<% end %>

<div class="px-4 py-2 rounded font-medium bg-blue-500 text-white hover:bg-blue-600 m-4"></div>
```

The helper reads argument hashes and arrays without changing them. You can reuse frozen arguments across calls. The `add` option also works when no YAML file exists.

Classy YAML checks component files, extra files, the default file, and engine files in that priority order. Base classes and specific classes fall back independently. Control options such as `skip_base` and `classy_files` are not YAML lookup keys.

### ViewComponent Integration

Include the component helpers in your ViewComponent:

```ruby
class ExampleComponent < ViewComponent::Base
  include Classy::Yaml::ComponentHelpers
end
```

This will automatically look for a sidecar file `example_component.yml` file alongside your component. For example:

```yaml
# config/utility_classes.yml
btn:
  base: "px-3 py-2"
  blue: "text-blue-200 bg-blue-500"
  yellow: "text-yellow-200 bg-blue-500"
  
  
# app/components/example_component/example_component.yml
btn:
  purple: "text-purple-200 bg-blue-500"


# app/components/example_component/example_component.html.erb

<button class="<%= yass(btn: :purple) %>">Classy Button</button>

# <button class="px-3 py-2 text-purple-200 bg-blue-500">Click me</button> 
```

## Tailwind Merge Integration

Classy YAML detects if [tailwind_merge](https://github.com/gjtorikian/tailwind_merge) is installed and will leverage it when fetching classes with `yass`. Please read their documentation for installation and benefits.


## Caching and development reloads

Classy YAML reuses parsed YAML when file metadata has not changed. In development and tests, each call checks the default, engine, extra, and component files. Edits, additions, and deletions take effect on the next call without a restart.

In production, the default and engine YAML remain cached until configuration resets or the process restarts. Extra and component files still receive metadata checks. `Classy::Yaml.setup` clears the YAML caches.

When `tailwind_merge` is available, Classy YAML reuses one merger per process in all environments. A lock protects the merger cache during concurrent calls.

## Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `default_file` | `"config/utility_classes.yml"` | Path to the main YAML file |
| `extra_files` | `[]` | Array of additional YAML files (above default and engine files; below component files) |
| `engine_files` | `[]` | Array of engine YAML files (lowest priority) |
| `override_tag_helpers` | `false` | Automatically process class symbols/hashes in Rails tag helpers |

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Tonksthebear/classy-yaml. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Classy::Yaml project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](CODE_OF_CONDUCT.md).
