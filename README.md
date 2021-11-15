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

<button class="<%=sass(btn: :purple)%>">Classy Button</button>

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

<button class="<%=sass(btn: :purple)%>">Classy Button</button>

# will add the classes "px-3 py-2 text-blue-50"
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
   "./app/components/**/*.yml" // If using component sidecar assets
]
```
## Contributing
This is my first attempt at an actual gem usable for all. Any and all suggestions are absolutely welcome. I'm not the cleanest programmer, so code quality suggestions are welcome too 👍 I extracted this logic from my private work and I felt it was useful enought to be worth publishing.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
