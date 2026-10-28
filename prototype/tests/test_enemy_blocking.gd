extends "res://tests/test_base.gd"
## Section 3: enemies block entry, cut-off holding, and the opposing entry policy.


func test_enemy_cutoff_settles_nearest_and_resumes() -> void:
	var s := make(["#########", ".........", "#########"], [["shaper", 0, 1]], [[5, 1]])
	var u = s.get_unit(1)
	var e = s.get_unit(2)
	order(s, u, "move", 8, 1)
	run_until(s, func(): return u.is_settled() and u.step == null and u.tile != T(0, 1), 200)
	eq(u.tile, T(4, 1), "settled at the nearest free tile to the target")
	eq(u.status, "blocked")
	check(u.reason.contains("enemy"), "shows the target as blocked by an enemy")
	check(u.order != null and u.order.target == T(8, 1), "keeps the target")
	run(s, 40)
	eq(u.tile, T(4, 1), "waits while cut off")
	s.kill(e)
	run_until(s, func(): return u.order == null, 200)
	check(settled_at(u, 8, 1), "continues when the route opens")


func test_cannot_enter_tile_an_enemy_is_entering() -> void:
	var s := make(["#########", ".........", "#########"], [["shaper", 2, 1]], [[4, 1]])
	var u = s.get_unit(1)
	var e = s.get_unit(2)
	order(s, e, "move", 3, 1)
	run(s, 1)
	check(e.step != null and e.step.to == T(3, 1), "enemy entering (3,1)")
	order(s, u, "move", 3, 1)
	run(s, 1)
	check(u.step == null, "player step into the entered tile denied")
	eq(s.opposing_ties, 0, "an earlier request is not a tie")


func test_opposing_tie_goes_to_player() -> void:
	var s := load_scenario("opposing_entry")
	s.enemy_ai = false
	s.spawning_enabled = false
	var u = s.get_unit(1)
	var e = s.enemy_units()[0]
	s.issue_order(e, "move", T(5, 2))
	s.issue_order(u, "move", T(5, 2))
	run(s, 1)
	check(u.step != null and u.step.to == T(5, 2), "player granted the gap")
	check(e.step == null, "enemy denied")
	eq(s.opposing_ties, 1, "tie counted")
	eq(e.status, "blocked", "denied enemy follows section 3.1")
	run_until(s, func(): return u.order == null)
	check(settled_at(u, 5, 2), "player holds the gap")


func test_opposing_tie_policy_switch() -> void:
	var data: Dictionary = Sim.load_json("res://scenarios/opposing_entry.json")
	data.tuning = {"opposing_entry_policy": "enemy_wins_ties"}
	var s := Sim.new()
	s.load_setup(data, tuning())
	s.enemy_ai = false
	s.spawning_enabled = false
	var u = s.get_unit(1)
	var e = s.enemy_units()[0]
	s.issue_order(u, "move", T(5, 2))
	s.issue_order(e, "move", T(5, 2))
	run(s, 1)
	check(e.step != null and e.step.to == T(5, 2), "enemy granted the gap")
	check(u.step == null, "player denied")
	eq(s.opposing_ties, 1)
	eq(u.status, "blocked")


func test_earlier_request_wins_across_ticks() -> void:
	var s := load_scenario("opposing_entry")
	s.enemy_ai = false
	s.spawning_enabled = false
	var u = s.get_unit(1)
	var e = s.enemy_units()[0]
	s.issue_order(e, "move", T(5, 2))
	run(s, 1)
	s.issue_order(u, "move", T(5, 2))
	run(s, 1)
	check(u.step == null, "later player request denied")
	eq(s.opposing_ties, 0)
	run(s, 30)
	eq(e.tile, T(5, 2), "enemy holds the gap")
	eq(u.tile, T(4, 2), "player waits at the nearest free tile")
	eq(u.status, "blocked")


func test_interrupted_movement_toward_work_position_by_friendly() -> void:
	var s := load_scenario("work_interrupted")
	var shaper = s.get_unit(1)
	var striker = s.get_unit(2)
	var work := T(5, 3)
	var pos := T(5, 2)
	var reachable := s.grid.adjacent_positions(work).filter(func(p): return s.grid.terrain_reachable(shaper.tile, p))
	eq(reachable, [pos], "single reachable work position")
	eq(s.command_default_action(shaper.id, work).action, "clear")
	run(s, 2)
	s.issue_order(striker, "attack_move", pos)
	run_until(s, func(): return striker.is_settled() and striker.order == null, 200)
	eq(striker.tile, pos, "striker took the work position")
	run_until(s, func(): return shaper.is_settled(), 200)
	eq(shaper.status, "holding", "work pending")
	eq(Hex.distance(shaper.tile, pos), 1, "holds at the nearest free tile")
	check(shaper.order != null and shaper.order.kind == "clear", "work kept")
	run(s, 40)
	check(s.grid.is_blocked(work), "no work done while waiting")
	s.issue_order(striker, "attack_move", T(9, 1))
	run_until(s, func(): return not s.grid.is_blocked(work), 400)
	check(not s.grid.is_blocked(work), "cleared after the work position freed")
	eq(shaper.tile, pos, "worked from the work position")


func test_interrupted_movement_toward_work_position_by_enemy() -> void:
	var s := load_scenario("work_interrupted")
	s.enemy_ai = false
	var shaper = s.get_unit(1)
	var work := T(5, 3)
	var pos := T(5, 2)
	s.command_default_action(shaper.id, work)
	var e = s.add_unit("enemy", Unit.Side.ENEMY, T(6, 1), "")
	s.tuning.units.enemy.damage = 0
	s.issue_order(e, "move", pos)
	run_until(s, func(): return shaper.is_settled() and shaper.tile != T(1, 1), 200)
	eq(e.tile, pos)
	eq(shaper.status, "blocked", "work position cut off by an enemy")
	check(shaper.order != null and shaper.order.kind == "clear", "work kept")
	s.kill(e)
	run_until(s, func(): return not s.grid.is_blocked(work), 400)
	check(not s.grid.is_blocked(work), "resumed and cleared")
