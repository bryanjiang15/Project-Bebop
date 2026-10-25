class_name SpellRules
extends RefCounted

## Affected tiles, range, and the reasons a cast is rejected.
## GameSetup applies a cast. This class does not touch units, cities, or fog.
## A radius is the target plus every tile within `radius` (radius 1 is 7 tiles).
## A line is the target plus the next tiles in one hex direction, `length` in all.
## Off-map tiles are dropped. Only the target has to be in range when
## `spells.only_target_must_be_in_range` is true.

const REASON_MANA := "Not enough mana"
const REASON_COOLDOWN := "On cooldown"
const REASON_TURN := "Already cast this turn"
const REASON_RANGE := "Out of range"
const REASON_HIDDEN := "Tile not revealed"
const REASON_OFF_MAP := "Cannot cast off the map"
const REASON_UNKNOWN := "Unknown spell"
const SKIP_CENTER := "City center"
const SKIP_UNIT := "Unit on tile"


static func affected_tiles(cfg: GameConfig, columns: int, rows: int, spell_id: String, target: Vector2i, direction: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if cfg == null or not cfg.spells.has(spell_id):
		return out
	var axial := Hex.offset_to_axial(target)
	if not Hex.in_map(axial, columns, rows):
		return out
	var stats := cfg.spell(spell_id)
	if stats.shape == "line":
		for hex in Hex.line(axial, direction, stats.length, columns, rows):
			out.append(Hex.axial_to_offset(hex))
		return out
	for hex in Hex.disk(axial, stats.radius):
		if Hex.in_map(hex, columns, rows):
			out.append(Hex.axial_to_offset(hex))
	return out


## -1 when the caster owns nothing. Otherwise the hex distance to the nearest owned tile.
static func nearest_owned_distance(target: Vector2i, owned: Array[Vector2i]) -> int:
	var best := -1
	var axial := Hex.offset_to_axial(target)
	for cell in owned:
		var dist := Hex.distance(axial, Hex.offset_to_axial(cell))
		if best < 0 or dist < best:
			best = dist
	return best


## Mana, cooldown, and the one-cast limit. No target yet.
static func block_reason(cfg: GameConfig, mana: int, casts_this_turn: int, cooldown_remaining: int, stats: GameConfig.SpellStats) -> String:
	if mana < stats.mana:
		return REASON_MANA
	if cooldown_remaining > 0:
		return REASON_COOLDOWN
	if casts_this_turn >= cfg.casts_per_turn:
		return REASON_TURN
	return ""


## Range is checked before the revealed flag. `in_range` is the target, or every
## affected tile when `only_target_must_be_in_range` is false.
static func target_reason(cfg: GameConfig, in_bounds: bool, in_range: bool, revealed: bool) -> String:
	if not in_bounds:
		return REASON_OFF_MAP
	if not in_range:
		return REASON_RANGE
	if cfg.spells_require_revealed_target and not revealed:
		return REASON_HIDDEN
	return ""


## The cursor's sector inside the hovered hex. `aim` and `axes` are offsets from
## the tile center. `axes` is one vector per hex direction, in Hex direction order.
## The center of the tile (a zero aim) is east, so a click with no offset is stable.
static func sector(aim: Vector2, axes: Array[Vector2]) -> int:
	if aim.length_squared() < 0.0001 or axes.is_empty():
		return Hex.EAST
	var best := 0
	var best_dot := -2.0
	var norm := aim.normalized()
	for dir in axes.size():
		var axis := axes[dir]
		if axis.length_squared() < 0.0001:
			continue
		var dot := norm.dot(axis.normalized())
		if dot > best_dot:
			best_dot = dot
			best = dir
	return best
