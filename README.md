# AI Helper Refill Source Fix

AI Helper Refill Source Fix fixes base game issues with AI helper refill sources for slurry, digestate, and manure spreaders in Farming Simulator 25.

> **Status:** Durability-test build available on GitHub; GIANTS ModHub listing pending.

## Download

- Test build: [v1.0.0.0-test on GitHub](https://github.com/CrankyAnt/FS25_AIHelperRefillSourceFix/releases/tag/v1.0.0.0-test).
- The official GIANTS ModHub listing will be linked here once published.

## What This Mod Does

Keeps AI helpers refilling from the source you selected. It fixes helpers ignoring the refill source shown in the settings menu, and manure sources that look selectable even though your farm cannot use them.

It covers slurry, digestate, and manure spreaders refilling from farm storages, animal pens, manure heaps, BGAs, or shared sources. It adds no new sources or storage capacity: a storage still needs to be registered by the game as a valid helper refill source.

## Compatibility

- Farming Simulator 25
- Multiplayer supported
- PC and Mac only, because this is a script mod

## Installation and Activation

1. Download the release package from [GitHub Releases](https://github.com/CrankyAnt/FS25_AIHelperRefillSourceFix/releases).
2. Place the package in your Farming Simulator 25 mods folder.
3. Enable the mod for the savegame.

Once published, the GIANTS ModHub listing becomes the preferred install route.

## Diagnostics

Release packages do not include diagnostics. To enable them, download `scripts/AIHelperRefillSourceDebug.lua` from the repository and place it in the `scripts` folder of the installed mod, next to `AIHelperRefillSourceFix.lua`.

Then add the script to `extraSourceFiles` in `modDesc.xml`:

```xml
<sourceFile filename="scripts/AIHelperRefillSourceDebug.lua" />
```

Use the following console command to toggle on-screen diagnostics and log output:

```text
aiHelperRefillDebug
```

The debug script is optional and does not affect the functional fix.

## Reporting Issues

Found a bug or compatibility issue? Please open a GitHub issue:

https://github.com/CrankyAnt/FS25_AIHelperRefillSourceFix/issues/new/choose

Please include:

- Farming Simulator 25 game version
- Platform: PC or Mac
- Singleplayer, multiplayer client, or multiplayer server / dedicated server
- Map name
- Fill type involved (slurry, digestate, manure)
- Selected refill source and observed source or error message
- Other relevant mods active in the savegame
- A short description of what happened and what you expected
- The game log, if the issue involves errors, multiplayer sync, or missing functionality; for multiplayer issues, include the server log if available

## License and Distribution

This repository uses per-file licensing according to the REUSE specification.
See [REUSE.toml](REUSE.toml) for the authoritative machine-readable license
assignment.

The functional Lua source code is licensed under the MIT License. The official
mod name, icon, branding, descriptions, and release packages are covered by
the separate CrankyAnt Official Assets License. See
[DISTRIBUTION.md](DISTRIBUTION.md) for a human-readable explanation.

## [Changelog](CHANGELOG.md)
