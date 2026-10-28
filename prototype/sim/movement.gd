extends RefCounted
## Movement rules from GAME_DESIGN.md#movement, sections 1-6.
##
## Every unit at a tile boundary (no step in progress) is planned once per tick in the
## request phase. A plan is computed without side effects, then executed. Steps are
## granted one at a time; a planned route grants no permission to move.

const Hex = preload("res://sim/hex.gd")
const Pathfinding = preload("res://sim/pathfinding.gd")
const Occupancy = preload("res://sim/occupancy.gd")
const Unit = preload("res://sim/unit.gd")
const Combat = preload("res://sim/combat.gd")

const FAR := 1 << 30


# --- Stopping positions -------------------------------------------------------------

## Tiles that satisfy the order: the target itself, or adjacent work/attack positions.
static func goal_tiles(sim, order) -> Array[Vector2i]:
	if order.kind == "clear":
		if not sim.grid.is_blocked(order.target):
			return []
		return sim.grid.adjacent_positions(order.target)
	if sim.grid.is_passable(order.target):
		return [order.target]
	return sim.grid.adjacent_positions(order.target)


## A free stopping position: passable, not entered or occupied by an enemy, and not
## claimed by another unit.
static func is_free_stop(sim, unit, t: Vector2i, blocked: Dictionary) -> bool:
	if not sim.grid.is_passable(t) or blocked.has(t):
		return false
	var o: int = sim.occupancy.claim_owner(unit.layer, t)
	return o == -1 or o == unit.id


## Section 2.2 ordering: walking distance to the target, then route length from the
## current tile, then stable tile order.
static func _better(a: Vector2i, b: Vector2i, wd: Dictionary, rl: Dictionary) -> bool:
	var wa: int = wd.get(a, FAR)
	var wb: int = wd.get(b, FAR)
	if wa != wb:
		return wa < wb
	var ra: int = rl[a]
	var rb: int = rl[b]
	if ra != rb:
		return ra < rb
	return Hex.less(a, b)


## Chooses where the unit should stop for the order.
## Result kinds:
##   "goal"         - a free goal tile is reachable.
##   "alternative"  - goals reachable but taken by others; nearest free tile (2.2).
##   "work_pending" - like alternative, for clearing: hold and keep the work (2.4).
##   "enemy_blocked"- enemies cut off every goal; nearest free tile, keep target (3.1).
##   "no_stop"      - no free stopping position is reachable at all.
static func choose_stop(sim, unit, order, blocked: Dictionary, prefer_first: Variant = null) -> Dictionary:
	var search := Pathfinding.search(sim.grid, unit.tile, blocked, prefer_first)
	var rl: Dictionary = search.dist
	var wd: Dictionary = sim.grid.walk_distance_field(order.target)
	var best: Variant = null
	var any_goal_reachable := false
	for g in goal_tiles(sim, order):
		if not rl.has(g):
			continue
		any_goal_reachable = true
		if is_free_stop(sim, unit, g, blocked) and (best == null or _better(g, best, wd, rl)):
			best = g
	var result := {"search": search, "stop": best, "kind": "goal"}
	if best != null:
		return result
	for t in rl:
		if is_free_stop(sim, unit, t, blocked) and (best == null or _better(t, best, wd, rl)):
			best = t
	result.stop = best
	if best == null:
		result.kind = "no_stop"
	elif any_goal_reachable:
		result.kind = "work_pending" if order.kind == "clear" else "alternative"
	else:
		result.kind = "enemy_blocked"
	return result


const KIND_STATUS := {
	"goal": "moving",
	"alternative": "moving",
	"work_pending": "holding",
	"enemy_blocked": "blocked",
	"no_stop": "blocked",
}
const KIND_REASON := {
	"goal": "",
	"alternative": "Destination taken: stopping at nearest free tile",
	"work_pending": "Work positions taken: waiting nearby",
	"enemy_blocked": "Target blocked by enemy",
	"no_stop": "No reachable stopping position",
}


# --- Planning (no side effects) -----------------------------------------------------

## Plan for a unit at a tile boundary. Actions:
##   "idle", "order_done", "hold", "blocked", "settle", "step".
static func plan(sim, unit, blocked: Dictionary) -> Dictionary:
	var order = unit.order
	if order == null:
		if unit.claim != null and unit.claim == unit.tile:
			return {"action": "idle"}
		# Not on a claimed stopping position: settle at the nearest free tile.
		order = Unit.Order.new("move", unit.tile, true)
	if order.kind == "clear" and not sim.grid.is_blocked(order.target):
		return {"action": "order_done"}
	if order.kind == "attack_move" and Combat.enemy_in_range(sim, unit):
		if is_free_stop(sim, unit, unit.tile, blocked):
			return {"action": "hold", "order": order}
		# In transit over a friendly: cannot fight here, keep moving to a free tile.
	var choice := choose_stop(sim, unit, order, blocked)
	if choice.stop == null:
		return {"action": "blocked", "order": order, "choice": choice}
	if choice.stop == unit.tile:
		return {"action": "settle", "order": order, "choice": choice}
	var r := Pathfinding.route(choice.search, choice.stop)
	return {"action": "step", "order": order, "choice": choice, "route": r,
		"next": r[1], "final": r[1] == choice.stop}


# --- Execution ----------------------------------------------------------------------

## Applies a plan. Returns the tile entered by a newly granted step, or null.
static func execute(sim, unit, p: Dictionary) -> Variant:
	if p.has("order") and unit.order != p.order:
		unit.order = p.order  # implicit settle order
	match p.action:
		"idle":
			_set_idle(unit)
			return null
		"order_done":
			unit.order = null
			_set_idle(unit)
			return execute(sim, unit, plan(sim, unit, Occupancy.hostile_blocked(sim.units, unit.side, unit.layer)))
		"hold":
			_settle_here(sim, unit)
			unit.status = "holding"
			unit.reason = "Enemy in range"
			unit.planned_stop = unit.tile
			unit.route = []
			return null
		"blocked":
			unit.status = "blocked"
			unit.reason = KIND_REASON["no_stop"]
			unit.planned_stop = null
			unit.route = []
			return null
		"settle":
			_settle_here(sim, unit)
			var kind: String = p.choice.kind
			unit.planned_stop = unit.tile
			unit.route = []
			unit.alternative = kind != "goal"
			if kind == "goal":
				if unit.order.kind == "clear":
					unit.status = "working"
					unit.reason = "Clearing"
				else:
					_complete_order(sim, unit, "")
			elif kind == "alternative":
				_complete_order(sim, unit, KIND_REASON["alternative"])
			else:
				unit.status = KIND_STATUS[kind]
				unit.reason = KIND_REASON[kind]
			return null
		"step":
			var kind: String = p.choice.kind
			var next: Vector2i = p.next
			if p.final:
				if not sim.occupancy.claim(unit.layer, next, unit.id):
					return null
				unit.stop_claim = next
			start_step(sim, unit, next)
			unit.status = KIND_STATUS[kind]
			unit.reason = KIND_REASON[kind]
			unit.planned_stop = p.choice.stop
			unit.alternative = kind != "goal"
			unit.route = p.route
			return next
	return null


static func _set_idle(unit) -> void:
	unit.status = "idle"
	unit.reason = ""
	unit.planned_stop = null
	unit.route = []
	unit.alternative = false


static func _complete_order(sim, unit, reason: String) -> void:
	unit.order = null
	unit.status = "idle"
	unit.reason = reason
	sim.emit_event({"type": "arrived", "unit": unit.id, "tile": unit.tile})


## Claims the current tile (section 2.1: claim immediately if already on it and free).
static func _settle_here(sim, unit) -> void:
	if unit.claim != null and unit.claim != unit.tile:
		sim.occupancy.release(unit.layer, unit.claim, unit.id)
	sim.occupancy.claim(unit.layer, unit.tile, unit.id)
	unit.claim = unit.tile


static func start_step(sim, unit, to: Vector2i) -> void:
	unit.step = Unit.Step.new(unit.tile, to, sim.tick_count)
	unit.step.progress = clampf(unit.carry, 0.0, 0.999)
	unit.carry = 0.0


# --- Advancing steps ----------------------------------------------------------------

static func advance(sim, unit, dt: float) -> void:
	var s = unit.step
	if s == null:
		return
	var delta: float = sim.speed(unit) * dt
	if s.returning:
		s.progress -= delta
		if s.progress <= 0.0:
			unit.carry = -s.progress
			unit.step = null
			sim.emit_event({"type": "returned", "unit": unit.id, "tile": unit.tile})
	else:
		s.progress += delta
		if s.progress >= 1.0:
			unit.carry = s.progress - 1.0
			_arrive(sim, unit)


## Section 4: logical position transfers on arrival. Section 2.1: the source claim is
## released when the first departing step completes.
static func _arrive(sim, unit) -> void:
	unit.tile = unit.step.to
	unit.step = null
	if unit.claim != null and unit.claim != unit.tile:
		sim.occupancy.release(unit.layer, unit.claim, unit.id)
		unit.claim = null
	if unit.stop_claim != null and unit.stop_claim == unit.tile:
		unit.claim = unit.tile
		unit.stop_claim = null


# --- New orders (section 5) ---------------------------------------------------------

## Called after a unit's order is replaced. Continue the current step if the new route
## starts with it; otherwise return to the source. Returning units keep returning.
static func on_order_changed(sim, unit) -> void:
	var s = unit.step
	if unit.is_changing_form() or s == null or s.returning:
		return
	var blocked := Occupancy.hostile_blocked(sim.units, unit.side, unit.layer)
	var keep := false
	var stop: Variant = null
	if unit.order != null:
		var choice := choose_stop(sim, unit, unit.order, blocked, s.to)
		stop = choice.stop
		if stop != null and stop != unit.tile:
			var r := Pathfinding.route(choice.search, stop)
			keep = r.size() >= 2 and r[1] == s.to
	if keep:
		if unit.stop_claim != null and unit.stop_claim != stop:
			sim.occupancy.release(unit.layer, unit.stop_claim, unit.id)
			unit.stop_claim = null
	else:
		cancel_step(sim, unit)


## Section 5.2: stop claiming entry, release the stopping claim, return to the source.
static func cancel_step(sim, unit) -> void:
	if unit.stop_claim != null:
		sim.occupancy.release(unit.layer, unit.stop_claim, unit.id)
		unit.stop_claim = null
	unit.step.returning = true
	unit.status = "returning"
	sim.emit_event({"type": "cancelled", "unit": unit.id, "tile": unit.tile})


# --- Request phase ------------------------------------------------------------------

## Order in which step requests are evaluated within a tick. Same-side conflicts resolve
## by stable unit ID (section 2.3); the policy decides which side wins opposing ties.
static func opposing_entry_order(units: Array, policy: String) -> Array:
	var first_side := Unit.Side.PLAYER
	if policy == "enemy_wins_ties":
		first_side = Unit.Side.ENEMY
	var out := []
	for u in units:
		if u.side == first_side:
			out.append(u)
	for u in units:
		if u.side != first_side:
			out.append(u)
	return out


static func request_phase(sim) -> void:
	var movers := []
	for u in sim.units:
		if u.step == null and not u.is_changing_form():
			movers.append(u)
	movers = opposing_entry_order(movers, sim.tuning.get("opposing_entry_policy", "player_wins_ties"))
	var blocked_by_side := {
		Unit.Side.PLAYER: Occupancy.hostile_blocked(sim.units, Unit.Side.PLAYER, Occupancy.GROUND),
		Unit.Side.ENEMY: Occupancy.hostile_blocked(sim.units, Unit.Side.ENEMY, Occupancy.GROUND),
	}
	# Tiles newly entered this tick by each side, to detect opposing ties (section 3.2).
	var entered_now := {Unit.Side.PLAYER: {}, Unit.Side.ENEMY: {}}
	for u in movers:
		if not u.alive:
			continue
		var opponent: int = Unit.Side.ENEMY if u.side == Unit.Side.PLAYER else Unit.Side.PLAYER
		var blocked: Dictionary = blocked_by_side[u.side]
		var opp_now: Dictionary = entered_now[opponent]
		if not opp_now.is_empty():
			# Re-plan as if this unit had been evaluated before the opponent's entries
			# this tick: without their entry blocks and their same-tick stop claims.
			var before := blocked.duplicate()
			var released := []
			for t in opp_now:
				before.erase(t)
				var owner_id: int = opp_now[t]
				if sim.occupancy.claim_owner(u.layer, t) == owner_id:
					sim.occupancy.release(u.layer, t, owner_id)
					released.append(t)
			var wanted := plan(sim, u, before)
			for t in released:
				sim.occupancy.claim(u.layer, t, opp_now[t])
			if wanted.action == "step" and opp_now.has(wanted.next):
				sim.opposing_ties += 1
				sim.emit_event({"type": "tie", "unit": u.id, "tile": wanted.next})
		var entered: Variant = execute(sim, u, plan(sim, u, blocked))
		if entered != null:
			var their_blocked: Dictionary = blocked_by_side[opponent]
			if not their_blocked.has(entered):
				their_blocked[entered] = true
				entered_now[u.side][entered] = u.id
	for u in sim.units:
		u.carry = 0.0
