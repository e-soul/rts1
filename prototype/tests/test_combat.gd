extends "res://tests/test_base.gd"
## Combat, attack-move holding, Guards plugging gaps, and the Core.

const Combat = preload("res://sim/combat.gd")


func test_target_selection_nearest_then_id() -> void:
	var s := make(field(9, 5), [["striker", 4, 2, "guard"]], [[7, 2], [1, 2], [6, 2]])
	var g = s.get_unit(1)
	eq(Combat.nearest_target(s, g, 4), 4, "nearest enemy")
	s.kill(s.get_unit(4))
	# (7,2) and (1,2) are both 3 away: lower ID wins.
	eq(Combat.nearest_target(s, g, 4), 2, "tie by stable ID")


func test_settled_striker_fights_automatically() -> void:
	var s := make(field(9, 5), [["striker", 4, 2, "assault"]], [[6, 2]])
	var e = s.get_unit(2)
	run_until(s, func(): return not e.alive, 200)
	check(not e.alive, "enemy killed by an idle striker")


func test_attack_move_holds_when_enemy_in_range_without_pursuing() -> void:
	# The enemy stands off the route, within range: the striker holds and fights,
	# never leaves its route, then continues to its destination.
	var s := make(field(12, 5), [["striker", 0, 2, "assault"]], [[5, 0]])
	var u = s.get_unit(1)
	var e = s.get_unit(2)
	s.tuning.units.enemy.damage = 0
	s.tuning.units.enemy.hp = 60
	e.hp = 60
	order(s, u, "attack_move", 11, 2)
	var held_at: Variant = null
	for i in range(400):
		s.tick()
		_invariants(s)
		check(u.tile.y == T(0, 2).y, "never leaves the route")
		if u.status == "holding" and held_at == null:
			held_at = u.tile
			check(u.is_settled(), "holding unit is settled")
		if u.order == null:
			break
	check(held_at != null, "held while the enemy was in range")
	check(not e.alive, "fought from the holding position")
	check(settled_at(u, 11, 2), "continued to its destination")


func test_selecting_enemy_tile_is_not_pursuit() -> void:
	var s := make(field(12, 3), [["striker", 0, 1, "assault"]], [[8, 1]])
	var e = s.get_unit(2)
	var res := s.command_default_action(1, e.tile)
	eq(res.action, "attack_move")
	order(s, e, "move", 11, 1)
	run(s, 5)
	eq(s.get_unit(1).order.target, T(8, 1), "order target stays the selected tile")


func test_transit_unit_cannot_attack_but_can_be_attacked() -> void:
	# An assault striker passes over two shapers while an enemy is in range. Over a
	# friendly it cannot shoot and does not hold; it remains a valid target.
	var s := make(["###########", "...........", "###########"],
		[["striker", 0, 1, "assault"], ["shaper", 4, 1], ["shaper", 5, 1]], [[7, 1]])
	s.tuning.units.enemy.hp = 100000
	s.tuning.units.enemy.damage = 0
	var u = s.get_unit(1)
	var e = s.get_unit(4)
	e.hp = 100000.0
	order(s, u, "attack_move", 9, 1)
	var targeted_in_transit := false
	for i in range(120):
		var shots_before: int = u.shots_fired
		s.tick()
		_invariants(s)
		if u.tile == T(4, 1) or u.tile == T(5, 1):
			check(u.in_transit(), "over a friendly means transit")
			eq(u.shots_fired, shots_before, "no shots while overlapping friendlies")
			if u.tile == T(5, 1) and Combat.nearest_target(s, e, 2) == u.id:
				targeted_in_transit = true
	check(targeted_in_transit, "transit unit can be targeted")
	eq(u.tile, T(6, 1), "held at the first free tile in range")
	check(u.is_settled() and u.status == "holding", "holding")
	check(u.shots_fired > 0, "shoots once settled")


func test_cancelled_attacks_gain_no_rate() -> void:
	# Two assault strikers next to a tough harmless enemy. One stays; the other gets a
	# new move order every few ticks. The moving one never fires more often.
	var s := make(field(12, 5), [["striker", 4, 2, "assault"], ["striker", 6, 3, "assault"]], [[5, 1]])
	s.tuning.units.enemy.hp = 100000
	s.tuning.units.enemy.damage = 0
	s.get_unit(3).hp = 100000
	var still = s.get_unit(1)
	var busy = s.get_unit(2)
	for i in range(100):
		if i % 3 == 0:
			s.issue_order(busy, "move", T(7, 3) if (i / 3) % 2 == 0 else T(6, 3))
		run(s, 2)
	check(still.shots_fired > 5, "the stationary striker kept firing (%d)" % still.shots_fired)
	check(busy.shots_fired <= still.shots_fired, "no attack-rate gain from movement (%d vs %d)" % [busy.shots_fired, still.shots_fired])


func test_guard_plugging_gap_is_fought_not_bypassed() -> void:
	var s := load_scenario("guard_gap")
	s.tuning.units.striker_guard.damage = 0  # a passive plug: enemies pile up against it
	var guard = s.get_unit(1)
	var core_before: float = s.core_hp
	var engaged := false
	for i in range(20 * 30):
		s.tick()
		_invariants(s)
		if not guard.alive:
			break
		for e in s.enemy_units():
			check(Hex.axial_to_offset(e.tile).x > 8, "enemy %d got past the guard" % e.id)
		if guard.hp < guard.max_hp:
			engaged = true
	check(engaged, "enemies attacked the guard")
	eq(s.core_hp, core_before, "core untouched while the guard holds")


func test_core_takes_damage_and_pauses_when_destroyed() -> void:
	var s := make(field(9, 7), [], [], {"rows": [
		".........", ".........", ".........", "....C....", ".........", ".........", ".........",
	], "enemies": [{"pos": [6, 3]}], "enemy_ai": true})
	s.core_hp = 20.0
	run_until(s, func(): return s.core_destroyed, 400)
	check(s.core_destroyed, "core destroyed")
	eq(s.core_hp, 0.0)
	var t := s.tick_count
	s.tick()
	eq(s.tick_count, t, "simulation stays paused")


func test_invulnerability_toggle() -> void:
	var s := make(field(9, 3), [["shaper", 3, 1]], [[4, 1]])
	s.invulnerable = true
	run(s, 200)
	eq(s.get_unit(1).hp, s.get_unit(1).max_hp, "no damage while invulnerable")
