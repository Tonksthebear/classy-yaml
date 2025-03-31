# Progress: Classy YAML

## Current Status
The gem is considered stable and functional for its core purpose: merging CSS utility classes from YAML files using the `yass` helper.

## What Works
- Loading default `config/utility_classes.yml`.
- Loading additional files specified in `config.extra_files`.
- `base:` key inheritance for shared styles within a group.
- `yass(key: :value)` helper for retrieving class strings.
- `skip_base: true` option to omit base classes.
- ViewComponent integration via `Classy::Yaml::ComponentHelpers`:
    - Prioritizing component sidecar YAML files (`component.yml`).
    - Merging/overriding global definitions with component-specific ones.
- Configuration via Rails initializer (`Classy::Yaml.setup`).
- Compatibility with Rails 7/ViewComponent 2.x and Rails 8 (main)/ViewComponent 3.x (as per Appraisals).

## What's Left / Next Steps
- Implement support for YAML arrays as values for class definitions.
- Analyze and potentially optimize the performance of class lookup/merging helpers.
- Add comprehensive tests for the new array functionality.
- Add tests for performance benchmarks (optional but good).

## Known Issues/Limitations
- Currently only supports string values in the YAML definitions; arrays are not handled.
- Performance with a very large number of YAML files or extremely complex definitions has not been benchmarked. 