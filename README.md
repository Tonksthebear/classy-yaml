# Classy::Yaml
This was created to provide convenient utility class grouping for environments without a bundler (or any situation where you might not want to add custom css classes). YAML files are a perfect structure for these situations.

## Usage
After installing the gem, the helper method `yass` will be available from anywhere. It looks for the definitions in the YAML file `config/utility_classes.yml` (note: you must add this yourself).

The YAML structure should follow this format:

```
btn:
  blue: "text-blue-200 bg-blue-500"
  yellow: "text-yellow-200 bg-blue-500"
```

Then, you can add these classes to any element by calling `yass(btn: :blue)` or `yass(btn: :yellow)`.

You may wonder though, what about shared classes you want all nested definitions to inherit? There is a special syntax for this type of inheritance:

```
btn:
  base: "px-3 py-2"
  blue: "text-blue-200 bg-blue-500"
  yellow: "text-yellow-200 bg-blue-500"
```

Now, calling `yass(btn: :blue)` or `yass(btn: :yellow)` will ALSO pull in the classes from `btn: :base`.

### Optionally Skipping Base

You can optionally skip including the base on a `yass` call by including the key/value `skip_base: true`. So, using the example above,
we can perform:
```
btn:
  base: "px-3 py-2"
  blue: "text-blue-200 bg-blue-500"
  yellow: "text-yellow-200 bg-blue-500"
```

Now, calling `yass(btn: :blue, skip_base: true)` and this will skip pulling in the classes from `btn: :base`. This is helpful
when defining animation classes and you only want to include the different classes, such as `active` and `inactive` for instance.

### ViewComponent
There is a special helper built for ViewComponent and sidecar assets. In your `example_component.rb`, add the line `include Classy::Yaml::ComponentHelpers`. This helper will tell `yass` to check if there is a `example_component.yml` file, and first use that for definitions. If the definitions aren't found in the `example_component.yml`, then it will fallback to `config/utility_classes.yml`.

So, it may look like this

```
# config/utility_classes.yml
btn:
  base: "px-3 py-2"
  blue: "text-blue-200 bg-blue-500"
  yellow: "text-yellow-200 bg-blue-500"
  
  
# app/components/example_component/example_component.yml
btn:
  purple: "text-purple-200 bg-blue-500"
  

# app/components/example_component/example_component.html.erb

<button class="<%=yass(btn: :purple)%>">Classy Button</button>

# will add the classes "px-3 py-2 text-purple-200 bg-blue-500"
```

As you can see, this will merge definitions found in the `ExampleComponent`'s sidecar asset with the main application's definitions. Not only will it merge, but it will overwrite them as well, allowing for true customization on a per-component basis:

```
# config/utility_classes.yml
btn:
  base: "px-3 py-2"
  blue: "text-blue-200 bg-blue-500"
  yellow: "text-yellow-200 bg-blue-500"
  
  
# app/components/example_component/example_component.yml
btn:
  blue: "text-blue-50"
  

# app/components/example_component/example_component.html.erb

<button class="<%=yass(btn: :purple)%>">Classy Button</button>

# will add the classes "px-3 py-2 text-blue-50"
```

yass(:button, :primary) # => "btn btn-primary"
yass(:button, :secondary) # => "btn btn-secondary"
yass(:button, :large) # => "btn btn-lg"
yass(:button, :primary, :large) # => "btn btn-primary btn-lg"

### Array style definition

```
array:
  - "px-3 py-2"
  - "bg-gray"
  - "text-purple"
```

yass(:array) # => "px-3 py-2 bg-gray text-purple"

## Configuration
You can configure the gem by creating an initializer in your Rails app. The following options are available:

```ruby
Classy::Yaml.setup do |config|
  # The default path for the utility classes YAML file 
  config.default_path = "config/utility_classes.yml"
  
  # Any extra files you want to load in addition to the default file. The last file loaded will overwrite any previous definitions
  config.extra_files = [
    "app/yamls/extra_styles.yml"
  ]
end
```

## Installation
Add this line to your application's Gemfile:

```ruby
gem 'classy-yaml'
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install classy-yaml
```

If using purging for styles, be sure to add the YAML files to the purge directories. For example, below is a tailwind.config.js:
```
purge: [
   "./config/utility_classes.yml",
   "./app/components/**/*.yml" // If using view component sidecar assets
]
```
## Contributing
This is my first attempt at an actual gem usable for all. Any and all suggestions are absolutely welcome. I'm not the cleanest programmer, so code quality suggestions are welcome too 👍 I extracted this logic from my private work and I felt it was useful enough to be worth publishing.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
