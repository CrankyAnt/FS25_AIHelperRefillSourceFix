# AI Helper Refill Source Fix

Fixes incorrect and inaccessible refill source selections for Farming Simulator 25 AI helpers using liquid manure or manure.

## What It Fixes

The base game stores helper refill sources in an internal list, while the settings menu can display a filtered version of that list. This can cause the menu to show a different source than the source actually used by the helper.

The manure menu can also show sources owned by another farm, even though the helper is not allowed to use them. Selecting such a source causes the helper to stop with the message "Tank is empty!"

This mod:

- Keeps displayed liquid manure and manure sources synchronized with the source actually selected.
- Hides manure sources that the active farm cannot access.
- Supports changing farms in multiplayer.
- Handles sources added dynamically during gameplay.

The mod does not add helper support to storage types or placeables that are not registered as valid helper refill sources by the game.

## Compatibility

- Farming Simulator 25
- Multiplayer supported
- PC only, because this is a script mod

## Optional Diagnostics

The durability-test build includes `scripts/AIHelperRefillSourceDebug.lua`.

Use the following console command to toggle diagnostics:

```text
aiHelperRefillDebug
```

The debug script and its `modDesc.xml` source-file entry can be removed without affecting the functional fix.

## Issues

Report issues on GitHub:
https://github.com/CrankyAnt/FS25_AIHelperRefillSourceFix/issues

## Changelog

### Version 1.0.0.0

- Initial release
