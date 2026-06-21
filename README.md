# AI Helper Refill Source Fix

AI Helper Refill Source Fix fixes base game issues with AI helper refill sources for slurry, digestate, and manure spreaders in Farming Simulator 25.

## Download

The official download will be available through GIANTS ModHub once published.

## What This Mod Does

Fixes AI helper refill source selection for slurry, digestate, and manure spreaders.
It is meant for saves where helpers can refill from farm storages, animal pens, manure heaps, BGAs, or shared sources, but the settings menu does not always match the source the helper actually uses. The mod keeps the selected source synchronized between the menu, the game state, and multiplayer clients.
It also hides manure sources the active farm cannot access, so helpers do not stop with "Tank is empty!" after selecting a source that looks available but cannot be used.
For slurry spreaders that already contain digestate, the helper keeps using digestate when digestate is available in the selected slurry source.
This mod does not add new refill sources or storage capacity. A storage or placeable still needs to be registered by the game as a valid helper refill source.

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

## Reporting Issues

Found a bug or compatibility issue? Please open a GitHub issue:

https://github.com/CrankyAnt/FS25_AIHelperRefillSourceFix/issues

Please open an issue and include:

- Farming Simulator 25 game version
- Platform: PC or Mac
- Singleplayer or multiplayer
- Map name
- Other relevant mods active in the savegame
- A short description of what happened and what you expected
- The game log, if the issue involves errors, multiplayer sync, or missing functionality

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
