extends "res://tests/test_base.gd"
## Every shipped setup loads and runs with invariants intact; random orders never break
## the movement rules; the simulation is deterministic.


func test_all_setups_load_and_run() -> void:
	var paths := Sim.list_setups()
	check(paths.size() >= 8, "found %d setups" % paths.size())
	eq(paths[0].get_file(), "sandbox.json", "sandbox listed first")
	for p in paths:
		var n: String = p.get_file()
		var s: Sim = Sim.from_file(p, tuning())
		check(s != null, "%s loads" % n)
		if s == null:
			continue
		check(not s.player_units().is_empty(), "%s has player units" % n)
		for u in s.units:
			check(s.grid.is_passable(u.tile), "%s: unit %d on a passable tile" % [n, u.id])
		run(s, 20 * 30)


func test_sandbox_spawns_enemies_and_core_is_reachable() -> void:
	var s := load_scenario("sandbox")
	check(s.has_core, "sandbox has a Core")
	check(s.spawn_points.size() >= 3, "several spawn points")
	var players := s.player_units().size()
	var spawned := 0
	for i in range(20 * 25):
		s.tick()
		_invariants(s)
		for e in s.take_events():
			if e.type == "spawned" and e.unit > players:
				spawned += 1
	check(spawned > 0, "enemies spawned")
	for u in s.player_units():
		check(s.grid.terrain_reachable(u.tile, s.core_center), "unit %d can reach the Core" % u.id)


func _fuzz(seed_value: int, ticks: int) -> Sim:
	var s := load_scenario("sandbox")
	s.invulnerable = true
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tiles: Array = s.grid.tiles
	for i in range(ticks):
		if i % 7 == 0:
			var units := s.player_units()
			var u = units[rng.randi_range(0, units.size() - 1)]
			var t: Vector2i = s.core_center + Vector2i(rng.randi_range(-8, 8), rng.randi_range(-8, 8))
			if rng.randf() < 0.1 and u.kind == Unit.STRIKER:
				s.command_toggle_form(u.id)
			else:
				s.command_default_action(u.id, t)
		s.tick()
		_invariants(s)
	return s


func _state(s: Sim) -> String:
	var parts := [str(s.tick_count), str(s.core_hp), str(s.grid.version)]
	for u in s.units:
		parts.append("%d:%s:%s:%s:%.3f:%s" % [u.id, u.tile, u.status, u.form,
			u.hp, u.step.to if u.step != null else "-"])
	return "|".join(parts)


func test_random_orders_keep_invariants() -> void:
	for seed_value in [1, 2, 3]:
		_fuzz(seed_value, 20 * 40)


func test_deterministic() -> void:
	eq(_state(_fuzz(42, 20 * 20)), _state(_fuzz(42, 20 * 20)), "same inputs, same state")
