# Product Context: Classy YAML

## Problem Solved
Managing CSS utility classes directly in templates or components can become verbose and repetitive. `classy-yaml` addresses this by allowing developers to define reusable groups of classes in YAML files, associating them with semantic keys.

## Target Audience
Ruby/Rails developers, particularly those:
- Working in environments without JavaScript bundlers or complex asset pipelines.
- Utilizing ViewComponent and seeking better ways to manage component-specific styles alongside global styles.
- Preferring a configuration-based approach (YAML) for defining style variations.
- Building applications or engines where styles need to be easily shared and potentially overridden.

## Desired User Experience
The ideal experience is seamless integration. Developers should be able to:
1. Define class groups easily in a central `utility_classes.yml` or component-specific `.yml` files.
2. Optionally define shared `base` classes for DRY definitions.
3. Include additional YAML files via configuration.
4. Use the simple `yass(key: :value)` helper in views/components to apply the correct classes.
5. Have component-specific definitions automatically take precedence over global ones.
6. Easily integrate definitions from Rails engines.
7. Configure the gem straightforwardly in an initializer. 