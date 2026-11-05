# AI Helper Refill Source Fix

The language of AI helper refilling in Farming Simulator 25 as this mod corrects it: which source a helper refills from, how the settings menu shows that source, and which farm may use it.

## Language

### Helpers and fill

**AI helper**:
A hired worker that drives a vehicle on its own and, while it works, refills it from its helper source.
_Avoid_: worker, AI worker

**Sprayer**:
A vehicle that spreads slurry or manure on a field and that an AI helper refills through external fill.
_Avoid_: spreader, tanker

**External fill**:
The refilling of an AI helper's sprayer from its helper source while it keeps working, without driving to the source.
_Avoid_: refill, helper refill

**Slurry**:
The category of liquid fill types that one helper source serves: liquid manure and digestate.
_Avoid_: liquid manure (for the category)

**Liquid manure**:
The fill type of liquid animal manure, one of the two slurry fill types.
_Avoid_: slurry (for the fill type)

**Digestate**:
The fill type that a biogas plant produces, the second slurry fill type.

**Manure**:
The fill type of solid animal manure, served by its own helper source.
_Avoid_: solid manure, dung

**Digestate preference**:
The rule that a sprayer already using digestate keeps receiving digestate while its slurry source can supply it, even when that source also holds liquid manure.

### Helper sources

**Helper source**:
The mission setting that tells AI helpers where to refill one fill category: Off, Buy, or a loading station. There are two: the slurry source and the manure source.
_Avoid_: refill source, helper setting

**Off**:
The helper source state in which an AI helper does not refill.

**Buy**:
The helper source state in which an AI helper buys its fill instead of taking it from a loading station.

**Loading station**:
A registered point in the world from which an AI helper can take fill; each helper source has its own list of them.
_Avoid_: refill point, registered source, station source

**Source storage**:
A storage that a loading station draws fill from; one loading station can draw from several.
_Avoid_: linked storage, extension storage

**Raw state**:
The number a helper source holds: 1 is Off, 2 is Buy, and every higher number is a position in that helper source's list of loading stations, offset by two.
_Avoid_: source value, station index

### Settings menu

**Refill option**:
The option in the in-game helper settings that shows and changes one helper source.
_Avoid_: refill menu, source dropdown

**Visible state**:
The position of the chosen entry among the entries a refill option shows, which differs from the raw state as soon as entries are left out.
_Avoid_: menu index, displayed source

**Station index mapping**:
The list that pairs each visible state of a refill option with its raw state.
_Avoid_: menu mapping, offset

### Farms and access

**Active farm**:
The farm the local player plays for at this moment; it can change during a multiplayer session.
_Avoid_: own farm, player farm

**Farm access**:
Whether a farm may take fill from a source storage of a loading station; a manure loading station without farm access is left out of the manure refill option.
_Avoid_: ownership

### Development

**Debug script**:
The optional diagnostics script that shows helper source, loading station and fill removal state on screen and in the log; release packages leave it out.
_Avoid_: diagnostics mod, debug mode
