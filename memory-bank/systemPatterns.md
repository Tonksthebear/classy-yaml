# System Patterns: Classy YAML

## Core Architecture
`classy-yaml` is a Ruby Gem designed to be included in Rails applications.

## Key Components & Patterns

1.  **Configuration (`Classy::Yaml.setup`):**
    *   Uses a standard Ruby block configuration pattern.
    *   Allows specifying the `default_path` for the main YAML file and an array of `extra_files`.

2.  **YAML Loading & Merging:**
    *   Loads YAML definitions from the configured default path, extra files, and potentially component sidecar files.
    *   Implements a merging strategy where definitions loaded later override earlier ones.
    *   Specific merging logic exists for ViewComponent sidecar files, prioritizing them over global definitions.
    *   Supports a special `base` key within a group for shared classes applied to all other keys in that group.

3.  **Helper Method (`yass`):**
    *   The primary interface for developers.
    *   Included as a Rails helper (globally) and potentially via `Classy::Yaml::ComponentHelpers` in ViewComponents.
    *   Takes a hash argument (e.g., `btn: :blue`).
    *   Looks up the corresponding classes in the loaded/merged YAML definitions.
    *   Handles retrieving and prepending `base` classes unless `skip_base: true` is provided.
    *   Returns a string of CSS classes.

4.  **ViewComponent Integration (`Classy::Yaml::ComponentHelpers`):**
    *   A specific module designed to be included in `ViewComponent::Base` subclasses.
    *   Modifies the lookup behavior of `yass` to first check for a component-specific YAML file (e.g., `example_component.yml` for `ExampleComponent`).
    *   Falls back to the globally configured YAML files if definitions are not found in the component's sidecar file.

## Data Flow
1.  Rails Initializer: Configures paths (`Classy::Yaml.setup`).
2.  Gem Load/Initialization: Loads YAML files from configured paths into memory.
3.  View Rendering: `yass(key: :value)` is called.
4.  Helper Logic:
    *   (If in ViewComponent w/ helper) Checks sidecar YAML.
    *   Checks global YAML definitions.
    *   Finds matching `key` and `value`.
    *   Retrieves associated class string.
    *   Retrieves `base` class string for the `key` (if exists and `skip_base` is not true).
    *   Combines and returns the final class string. 