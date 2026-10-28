extends RefCounted
## Player control model: one selected unit, one selected tile, no groups.
## The gamepad layer and the tests issue the same commands through this object.

const Hex = preload("res://sim/hex.gd")

var sim
var selected_id := -1
var cursor := Vector2i.ZERO
var last_result: Dictionary = {}


func _init(simulation) -> void:
	sim = simulation
	cursor = sim.camera_start
	var units: Array = sim.player_units()
	selected_id = units[0].id if not units.is_empty() else -1


func selected() -> Variant:
	return sim.get_unit(selected_id)


## Keeps the selection on a living unit: if the selected unit died, select the next one.
func ensure_selection() -> void:
	if sim.get_unit(selected_id) != null:
		return
	var units: Array = sim.player_units()
	if units.is_empty():
		selected_id = -1
		return
	for u in units:
		if u.id > selected_id:
			selected_id = u.id
			return
	selected_id = units[0].id


## LB/RB: cycle living units in stable order, wrapping. Tile and camera are preserved.
func select_next() -> void:
	_cycle(1)


func select_prev() -> void:
	_cycle(-1)


func _cycle(delta: int) -> void:
	var units: Array = sim.player_units()
	if units.is_empty():
		selected_id = -1
		return
	var idx := -1
	for i in range(units.size()):
		if units[i].id == selected_id:
			idx = i
	if idx == -1:
		ensure_selection()
		return
	selected_id = units[posmod(idx + delta, units.size())].id


func move_cursor(dir: int) -> bool:
	var t := Hex.neighbor(cursor, dir)
	if not sim.grid.in_map(t):
		return false
	cursor = t
	return true


func set_cursor(t: Vector2i) -> void:
	if sim.grid.in_map(t):
		cursor = t


func preview() -> Dictionary:
	return sim.preview_default_action(selected_id, cursor)


## A: the selected unit's default action on the selected tile.
func default_action() -> Dictionary:
	last_result = sim.command_default_action(selected_id, cursor)
	return last_result


## X: Striker form change.
func ability() -> Dictionary:
	last_result = sim.command_toggle_form(selected_id)
	return last_result


## B: cancel an open interaction. Nothing opens interactions in this scope; it never
## stops units or clears the selection.
func cancel() -> Dictionary:
	last_result = {"ok": false, "reason": "Nothing to cancel"}
	return last_result
