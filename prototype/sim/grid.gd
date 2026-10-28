extends RefCounted
## Terrain and structure footprints. Cleared tiles stay cleared.

const Hex = preload("res://sim/hex.gd")
const Pathfinding = preload("res://sim/pathfinding.gd")

enum Terrain { CLEARED, BLOCKED }

var width := 0
var height := 0
var terrain: Dictionary = {}       # Vector2i -> Terrain
var footprint: Dictionary = {}     # Vector2i -> structure id (String)
var clear_progress: Dictionary = {}  # Vector2i -> seconds of work done
## Incremented whenever terrain changes; caches key on it.
var version := 0
var tiles: Array[Vector2i] = []    # all map tiles in stable order
var _walk_cache: Dictionary = {}


func setup_from_rows(rows: Array) -> void:
	height = rows.size()
	width = 0
	terrain.clear()
	tiles.clear()
	for row in range(rows.size()):
		var line: String = rows[row]
		width = maxi(width, line.length())
		for col in range(line.length()):
			var ch := line[col]
			if ch == " ":
				continue
			var t := Hex.offset_to_axial(col, row)
			terrain[t] = Terrain.BLOCKED if ch == "#" else Terrain.CLEARED
			tiles.append(t)
	tiles.sort_custom(Hex.less)
	version += 1
	_walk_cache.clear()


func in_map(t: Vector2i) -> bool:
	return terrain.has(t)


func is_blocked(t: Vector2i) -> bool:
	return terrain.get(t, Terrain.BLOCKED) == Terrain.BLOCKED


func is_cleared(t: Vector2i) -> bool:
	return terrain.has(t) and terrain[t] == Terrain.CLEARED


## Ground units may stand on cleared tiles outside structure footprints.
func is_passable(t: Vector2i) -> bool:
	return is_cleared(t) and not footprint.has(t)


func set_cleared(t: Vector2i) -> void:
	if terrain.has(t) and terrain[t] != Terrain.CLEARED:
		terrain[t] = Terrain.CLEARED
		clear_progress.erase(t)
		version += 1
		_walk_cache.clear()


func passable_neighbors(t: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for n in Hex.neighbors(t):
		if is_passable(n):
			out.append(n)
	return out


## Tiles that make up the target region: a structure's footprint, or the tile itself.
func region_of(t: Vector2i) -> Array[Vector2i]:
	if footprint.has(t):
		var id: String = footprint[t]
		var out: Array[Vector2i] = []
		for f in footprint:
			if footprint[f] == id:
				out.append(f)
		return out
	return [t]


## Passable tiles adjacent to an impassable target region (work or attack positions).
func adjacent_positions(t: Vector2i) -> Array[Vector2i]:
	var region := region_of(t)
	var seen := {}
	var out: Array[Vector2i] = []
	for r in region:
		for n in passable_neighbors(r):
			if not seen.has(n):
				seen[n] = true
				out.append(n)
	out.sort_custom(Hex.less)
	return out


## Walking distance to the target over passable terrain, ignoring units.
## An impassable target is reached from its adjacent positions (distance 1).
func walk_distance_field(target: Vector2i) -> Dictionary:
	if _walk_cache.has(target):
		return _walk_cache[target]
	var field: Dictionary
	if is_passable(target):
		field = Pathfinding.distance_field(self, [target], 0, {})
	else:
		field = Pathfinding.distance_field(self, adjacent_positions(target), 1, {})
	_walk_cache[target] = field
	return field


## True if the target can be reached (or worked/attacked from adjacent) over known terrain.
func terrain_reachable(from: Vector2i, target: Vector2i) -> bool:
	return walk_distance_field(target).has(from)
