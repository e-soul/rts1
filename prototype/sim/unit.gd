extends RefCounted
## Shared unit state. Behaviour lives in movement.gd, combat.gd, shaper.gd, striker.gd, enemy.gd.

enum Side { PLAYER, ENEMY }

const STRIKER := "striker"
const SHAPER := "shaper"
const ENEMY := "enemy"


## A step between neighbouring tiles. Logical position stays at `from` until arrival.
class Step:
	extends RefCounted
	var from: Vector2i
	var to: Vector2i
	var progress := 0.0      # 0 at `from`, 1 at `to`
	var returning := false   # cancelled: moving back to `from`
	var started_tick := 0

	func _init(a: Vector2i, b: Vector2i, tick: int) -> void:
		from = a
		to = b
		started_tick = tick


## A movement or work order. kind: "move", "attack_move", "clear".
class Order:
	extends RefCounted
	var kind := ""
	var target: Vector2i
	var implicit := false    # generated to settle a unit that has no stopping position

	func _init(k: String, t: Vector2i, is_implicit := false) -> void:
		kind = k
		target = t
		implicit = is_implicit


var id := 0
var side := Side.PLAYER
var kind := ""
var form := ""               # strikers: "assault" or "guard"
var layer := 0
var alive := true

var hp := 0.0
var max_hp := 0.0

var tile := Vector2i.ZERO    # logical position
var step: Step = null
var claim: Variant = null    # Vector2i of the stopping claim held where the unit stands or stood
var stop_claim: Variant = null  # Vector2i claimed together with the final step
var carry := 0.0             # step progress overflow carried into the next step this tick

var order: Order = null
## "idle", "moving", "holding", "blocked", "working", "changing_form"
var status := "idle"
var reason := ""
var planned_stop: Variant = null
var route: Array = []
var alternative := false     # planned_stop is an alternative to the order target

var form_change_left := 0.0

var cooldown := 0.0
var windup := -1.0           # < 0: not winding up an attack
var windup_target := -1
var shots_fired := 0


func is_player() -> bool:
	return side == Side.PLAYER


## Settled: no step in progress and standing on a stopping position it has claimed.
func is_settled() -> bool:
	return step == null and claim != null and claim == tile


func in_transit() -> bool:
	return not is_settled()


func is_changing_form() -> bool:
	return form_change_left > 0.0


## Transit units cannot attack, work, or change form (section 6.1).
func can_act() -> bool:
	return alive and is_settled() and not is_changing_form()


func stats_key() -> String:
	if kind == STRIKER:
		return "striker_" + form
	return kind


func label() -> String:
	if kind == STRIKER:
		return "%s %s #%d" % [form.capitalize(), "Striker", id]
	return "%s #%d" % [kind.capitalize(), id]


func short_label() -> String:
	match kind:
		STRIKER:
			return "G" if form == "guard" else "A"
		SHAPER:
			return "S"
	return "E"
