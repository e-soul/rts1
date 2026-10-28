extends "res://tests/test_base.gd"
## Sections 1, 2, 4 and 6: friendly passage, exclusive stopping, logical position, transit.


func test_move_timing_and_logical_position() -> void:
	# Shaper speed 2.5 tiles/s = 8 ticks per step; the first step starts on tick 1.
	var s := make(field(7, 3), [["shaper", 0, 1]])
	var u = s.get_unit(1)
	order(s, u, "move", 4, 1)
	run(s, 5)
	eq(u.tile, T(0, 1), "logical position stays at source until arrival")
	check(u.step != null and u.step.to == T(1, 1), "first step in progress")
	var ticks := run_until(s, func(): return settled_at(u, 4, 1) and u.order == null)
	eq(ticks + 5, 33, "4 steps * 8 ticks + 1 tick to start")


func test_stopping_claim_granted_with_final_step() -> void:
	var s := make(field(7, 3), [["shaper", 0, 1]])
	var u = s.get_unit(1)
	order(s, u, "move", 3, 1)
	run(s, 1)
	eq(s.occupancy.claim_owner(0, T(0, 1)), 1, "source claim kept during first step")
	eq(s.occupancy.claim_owner(0, T(3, 1)), -1, "target not claimed before final step")
	run(s, 8)  # first step completes on tick 9
	eq(u.tile, T(1, 1))
	eq(s.occupancy.claim_owner(0, T(0, 1)), -1, "source claim released when first step completes")
	eq(s.occupancy.claim_owner(0, T(3, 1)), -1, "still not claimed: not the final step")
	run(s, 8)  # tick 17: final step starts
	eq(u.step.to, T(3, 1))
	eq(s.occupancy.claim_owner(0, T(3, 1)), 1, "claim granted together with the final step")
	check(u.in_transit(), "moving unit is in transit")


func test_shared_destination_all_settle_on_distinct_tiles() -> void:
	var s := load_scenario("shared_destination")
	var dest := T(12, 4)
	for u in s.player_units():
		s.issue_order(u, "attack_move", dest)
	run_until(s, func(): return s.player_units().all(func(u): return u.is_settled() and u.order == null), 600)
	var tiles := {}
	for u in s.player_units():
		check(u.is_settled(), "unit %d settled" % u.id)
		check(not tiles.has(u.tile), "unit %d alone on its tile" % u.id)
		tiles[u.tile] = true
	eq(s.occupancy.claim_owner(0, dest) != -1, true, "someone holds the destination")
	for u in s.player_units():
		check(Hex.distance(u.tile, dest) <= 2, "unit %d stopped near the destination" % u.id)


func test_nearer_unit_ordered_after_distant_unit_takes_the_tile() -> void:
	var s := load_scenario("shared_destination")
	var dest := T(12, 4)
	var far = s.get_unit(1)
	var near = s.get_unit(4)
	s.issue_order(far, "attack_move", dest)
	run(s, 10)
	s.issue_order(near, "move", dest)
	run_until(s, func(): return far.is_settled() and far.order == null and near.is_settled() and near.order == null, 600)
	eq(near.tile, dest, "nearer unit took the destination")
	eq(Hex.distance(far.tile, dest), 1, "distant unit chose an adjacent alternative")
	check(far.alternative, "distant unit marked as stopped at an alternative")


func test_simultaneous_claims_resolve_by_unit_id() -> void:
	# Units 1 and 2 are each one step from the target and are ordered in the same tick,
	# in reverse ID order: the lower ID still wins (section 2.3).
	var s := make(field(7, 3), [["shaper", 2, 1], ["shaper", 4, 1]])
	var a = s.get_unit(1)
	var b = s.get_unit(2)
	order(s, b, "move", 3, 1)
	order(s, a, "move", 3, 1)
	run(s, 1)
	eq(a.stop_claim, T(3, 1), "lower ID granted the claim")
	check(b.planned_stop != T(3, 1), "higher ID chose an alternative")
	run_until(s, func(): return a.is_settled() and b.is_settled() and a.order == null and b.order == null)
	eq(a.tile, T(3, 1))
	check(b.tile != T(3, 1), "loser stopped elsewhere")


func test_friendly_crossing_and_passage_through_guard() -> void:
	var s := load_scenario("friendly_crossing")
	var guard = s.get_unit(1)
	var targets := {2: T(16, 3), 3: T(16, 4), 4: T(2, 3), 5: T(2, 2)}
	for id in targets:
		var u = s.get_unit(id)
		s.issue_order(u, "attack_move" if u.kind == "striker" else "move", targets[id])
	var overlapped_guard := false
	var shared_tile := false
	for i in range(400):
		s.tick()
		_invariants(s)
		for u in s.player_units():
			if u.id != guard.id and u.tile == guard.tile:
				overlapped_guard = true
				check(u.in_transit() and not u.can_act(), "unit over the guard is in transit")
		var movers := targets.keys().map(func(id): return s.get_unit(id))
		for a in movers:
			for b in movers:
				if a.id >= b.id:
					continue
				if a.tile == b.tile:
					shared_tile = true
				if a.step != null and b.step != null and a.step.from == b.step.to and a.step.to == b.step.from:
					shared_tile = true
		check(guard.is_settled() and guard.tile == T(9, 3), "guard never displaced")
	for id in targets:
		var u = s.get_unit(id)
		check(u.is_settled() and u.tile == targets[id], "unit %d arrived" % id)
	check(overlapped_guard, "units passed through the guard's tile")
	check(shared_tile, "opposing friendlies shared or swapped tiles while crossing")


func test_crossing_takes_no_longer_than_unobstructed() -> void:
	# The east-bound shaper's time through the busy corridor equals its time alone.
	var busy := load_scenario("friendly_crossing")
	var alone := load_scenario("friendly_crossing")
	for id in [2, 4, 5]:
		alone.kill(alone.get_unit(id))
	alone.kill(alone.get_unit(1))
	var dest := T(16, 4)
	busy.issue_order(busy.get_unit(3), "move", dest)
	busy.issue_order(busy.get_unit(4), "attack_move", T(2, 3))
	busy.issue_order(busy.get_unit(5), "move", T(2, 2))
	alone.issue_order(alone.get_unit(3), "move", dest)
	var t_busy := run_until(busy, func(): return busy.get_unit(3).is_settled() and busy.get_unit(3).order == null)
	var t_alone := run_until(alone, func(): return alone.get_unit(3).is_settled() and alone.get_unit(3).order == null)
	check(t_busy > 0, "arrived")
	eq(t_busy, t_alone, "friendlies never block passage")


func test_blocked_unit_overlapping_friendly_loses_every_stop() -> void:
	var s := load_scenario("blocked_overlap")
	var u = s.get_unit(4)
	var rear = s.get_unit(5)   # enemy behind
	var front = s.get_unit(6)  # enemy beyond the free tile
	order(s, u, "move", 6, 2)
	run(s, 9)
	eq(u.tile, T(3, 2), "first step done, now over a friendly")
	eq(s.occupancy.claim_owner(0, T(2, 2)), -1, "source released")
	order(s, rear, "move", 2, 2)
	order(s, front, "move", 6, 2)
	run(s, 8)
	eq(u.tile, T(4, 2), "arrived over the second friendly")
	eq(u.status, "blocked", "no stopping position reachable")
	check(u.step == null, "not moving")
	check(u.claim == null and u.in_transit(), "still in transit, overlapping")
	check(not u.can_act(), "overlap restrictions apply")
	eq(s.get_unit(2).tile, T(4, 2))
	check(s.get_unit(2).is_settled(), "stationary friendly unaffected")
	run(s, 20)
	eq(u.tile, T(4, 2), "remains blocked in place")
	# Free the rear tile: it walks back to the nearest free tile, keeping the target.
	s.kill(rear)
	run_until(s, func(): return u.is_settled(), 100)
	eq(u.tile, T(2, 2), "settled at the nearest free tile")
	eq(u.status, "blocked", "target still blocked by enemy")
	check(u.order != null and u.order.target == T(6, 2), "target kept")
	s.kill(front)
	run_until(s, func(): return u.order == null, 200)
	check(settled_at(u, 6, 2), "continued to its target when the route opened")


func test_death_removes_unit_claims_and_step() -> void:
	var s := make(field(7, 3), [["shaper", 0, 1]])
	var u = s.get_unit(1)
	order(s, u, "move", 1, 1)
	run(s, 3)
	eq(s.occupancy.claim_owner(0, T(1, 1)), 1)
	s.kill(u)
	eq(s.occupancy.claim_owner(0, T(0, 1)), -1, "source claim removed")
	eq(s.occupancy.claim_owner(0, T(1, 1)), -1, "stop claim removed")
	check(u.step == null and s.get_unit(1) == null, "unit and step removed")


func test_unit_without_stopping_position_settles_nearest() -> void:
	# A transit unit that lost its order settles at the nearest free tile on its own.
	var s := make(field(7, 3), [["shaper", 3, 1], ["shaper", 0, 1]])
	var u = s.get_unit(2)
	order(s, u, "move", 5, 1)
	run_until(s, func(): return u.tile == T(3, 1))
	# Drop the order while passing over unit 1 (no player command does this; it
	# exercises the implicit settle for units without a stopping position).
	u.order = null
	run_until(s, func(): return u.is_settled(), 100)
	check(u.is_settled() and u.tile != T(3, 1), "left the friendly's tile and settled")
	eq(Hex.distance(u.tile, T(3, 1)), 1, "nearest free tile")
