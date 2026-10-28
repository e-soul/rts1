extends RefCounted
## Stopping claims per movement layer. Only the ground layer is used in this prototype;
## the air layer exists so flyers can be added without changing the data model.
## Logical occupancy (a unit's tile) and entering steps live on the units themselves;
## the helpers below derive per-side views from them.

const GROUND := 0
const AIR := 1
const LAYER_COUNT := 2

var claims: Array[Dictionary] = []  # per layer: Vector2i -> unit id


func _init() -> void:
	for i in range(LAYER_COUNT):
		claims.append({})


func claim_owner(layer: int, tile: Vector2i) -> int:
	return claims[layer].get(tile, -1)


## Grants the claim if the tile is unclaimed or already claimed by this unit.
func claim(layer: int, tile: Vector2i, unit_id: int) -> bool:
	var current: int = claims[layer].get(tile, -1)
	if current != -1 and current != unit_id:
		return false
	claims[layer][tile] = unit_id
	return true


func release(layer: int, tile: Vector2i, unit_id: int) -> void:
	if claims[layer].get(tile, -1) == unit_id:
		claims[layer].erase(tile)


func clear() -> void:
	for c in claims:
		c.clear()


## Tiles that units of `side` may not enter: occupied or being entered by the other side.
static func hostile_blocked(units: Array, side: int, layer: int) -> Dictionary:
	var blocked := {}
	for u in units:
		if u.side == side or u.layer != layer:
			continue
		blocked[u.tile] = true
		if u.step != null and not u.step.returning:
			blocked[u.step.to] = true
	return blocked


## Units whose logical position is the tile.
static func occupants(units: Array, tile: Vector2i, layer: int) -> Array:
	var out := []
	for u in units:
		if u.layer == layer and u.tile == tile:
			out.append(u)
	return out


## True if no unit of any side occupies, enters, or claims the tile.
func is_empty(units: Array, tile: Vector2i, layer: int) -> bool:
	if claim_owner(layer, tile) != -1:
		return false
	for u in units:
		if u.layer != layer:
			continue
		if u.tile == tile:
			return false
		if u.step != null and not u.step.returning and u.step.to == tile:
			return false
	return true
