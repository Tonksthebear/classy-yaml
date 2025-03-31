# Project Brief: Classy YAML

## Core Purpose
The primary goal of the `classy-yaml` gem is to provide a convenient utility for grouping CSS utility classes defined in YAML files. It aims to simplify class management in Ruby/Rails environments, particularly those without complex asset bundling pipelines or those utilizing component architectures like ViewComponent.

## Scope
- **In Scope:** Parsing YAML files (`config/utility_classes.yml` by default, component-specific `.yml` files, and configured `extra_files`) to extract CSS class strings, merging definitions (including a `base` key for inheritance), providing a helper method (`yass`) for easy integration into views/components, and allowing optional skipping of base classes. Compatibility with Rails 7 and future Rails 8 (Sprockets & Propshaft) and ViewComponent.
- **Out of Scope (Currently):** Advanced CSS processing, integration with specific CSS frameworks beyond providing class strings, complex conditional logic within YAML definitions (beyond the current `base` inheritance and `skip_base`). 