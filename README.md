# AI Helper Refill Source Fix

AI Helper Refill Source Fix fixes base game issues with AI helper refill sources for slurry, digestate, and manure spreaders in Farming Simulator 25.

## What It Fixes

The base game stores helper refill sources in internal lists, while the settings menu can display a filtered version of those lists. This can cause the menu to show a different source than the source actually used by the helper.

This mod keeps the refill source shown in the settings menu synchronized with the source actually used by the helper. That prevents helpers from drawing from a different storage than the one selected, or stopping with "Tank is empty!" while the selected source still contains material.

The mod also fixes related helper refill issues:

- Hides manure sources that the active farm cannot access.
- Keeps multiplayer clients synchronized with the server after loading or joining.
- Keeps digestate active when a slurry spreader is already using digestate and the selected source can supply it.

The mod does not add new refill sources. A storage or placeable still needs to be registered by the game as a valid helper refill source.

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

## License and Distribution

This repository uses per-file licensing according to the REUSE specification.
See [REUSE.toml](REUSE.toml) for the authoritative machine-readable license
assignment.

The functional Lua source code is licensed under the MIT License. The official
mod name, icon, branding, descriptions, and release packages are covered by
the separate CrankyAnt Official Assets License. See
[DISTRIBUTION.md](DISTRIBUTION.md) for a human-readable explanation.

## Changelog

### Version 1.0.0.0

- Initial test release.
- Fixes helper refill source menu synchronization for slurry and manure.
- Filters inaccessible manure sources for the active farm.
- Synchronizes multiplayer clients with the server after loading or joining.
- Keeps digestate active when the spreader already uses digestate and the selected source can supply it.
- Adds optional diagnostics for durability testing.
