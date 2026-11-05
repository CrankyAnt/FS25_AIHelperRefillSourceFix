# Translate the visible state and leave the raw source lists alone

The base game passes a raw state to a refill option that expects a visible state, so the menu shows a different loading station than the AI helper uses as soon as entries are left out. The fix sits at the menu boundary: the mod translates between raw and visible state through the station index mapping, and it never reorders, filters or extends the game's loading station lists and never registers new loading stations. Every saved helper source in existing savegames is a raw state into those lists, so a fix that changed the lists would silently move saved selections, and any later reversal would move them again.

## Considered Options

- **Reorder or filter the loading station lists to match the menu**: removes the translation, but changes what every saved raw state points at and touches the AI helper's own consumption.
- **Register every storage that supports the fill type as a loading station**: makes more storages usable, but storages that support a fill type were not all meant as helper sources, it can expose inputs and unrelated linked storages, and it shifts the lists as well.
- **Translate at the menu boundary** (this decision): the saved raw states stay the game's own, and external fill keeps resolving a loading station from the raw state as the game does; only the menu deals with the visible state.

## Consequences

- A storage that the game does not expose through a loading station stays unusable for AI helpers; the mod does not repair placeable configuration.
- Every change that filters a refill option must rebuild its station index mapping in the same step.
