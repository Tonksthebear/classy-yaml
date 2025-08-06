# Active Context: Classy YAML

## Current Focus
Successfully implemented and tested the `override_tag_helpers` configuration option that allows automatic integration of Classy YAML with Rails tag helpers. This feature enables automatic processing of class symbols and hashes through the `yass` helper when using Rails tag methods.

## Recent Changes
- ✅ Added `override_tag_helpers` configuration option to `Classy::Yaml`
- ✅ Implemented automatic tag helper override that processes class options through `yass`
- ✅ Removed the separate `lib/action_view/` directory as overriding is now handled through configuration
- ✅ Updated implementation to work with Rails 7+ `TagBuilder` class instead of deprecated `tag_options`
- ✅ Added comprehensive tests for the new configuration option
- ✅ All tests passing across Rails 7, 8 (Sprockets), and 8 (Propshaft)
- ✅ Fixed recursive call issues and method aliasing problems
- ✅ Added proper test isolation to ensure override can be toggled on/off
- ✅ **NEW**: Added optional `tailwind_merge` gem integration for intelligent CSS class merging
- ✅ **NEW**: Implemented automatic detection of `tailwind_merge` availability
- ✅ **NEW**: Added fallback to simple class joining when `tailwind_merge` is not available
- ✅ **NEW**: Added comprehensive tests for the tailwind_merge integration

## Next Steps
1. **Documentation:** Update README to document the new `override_tag_helpers` feature
2. **Documentation:** Update README to document the new `tailwind_merge` integration feature
3. **Examples:** Provide usage examples showing how the tag helper override works
4. **Examples:** Provide usage examples showing how tailwind_merge integration works
5. **Consider:** Whether to add similar override functionality for other Rails helpers (like `content_tag`)
6. **Optimize:** Evaluate if there are any performance considerations for the tag helper override
7. **Testing:** Add integration tests with actual tailwind_merge gem when available

## Active Decisions & Considerations
- The override only processes `:class` options that are Symbols or Hashes
- The override is applied automatically when `override_tag_helpers = true` is set in configuration
- The implementation uses Rails 7+ compatible `TagBuilder` class and overrides the `tag_options` method
- The feature maintains backward compatibility with existing `yass` helper usage
- Tests properly isolate the override functionality to ensure it can be toggled on/off
- The override correctly handles nested hash classes and preserves other tag options
- **NEW**: `tailwind_merge` integration is optional and automatically detected
- **NEW**: When `tailwind_merge` is available, it's used for intelligent class merging
- **NEW**: When `tailwind_merge` is not available, the system falls back to simple space-joined classes
- **NEW**: The availability check is cached to avoid repeated require attempts
- **NEW**: `tailwind_merge` is added as a development dependency for testing purposes 