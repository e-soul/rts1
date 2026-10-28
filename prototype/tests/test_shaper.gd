extends "res://tests/test_base.gd"
## Shaper clearing: timing, permanence, cooperative work, and rejections.

const ROOM := [
	"#########",
	"#.......#",
	"#...#...#",
	"#.......#",
	"#########",
]


func test_clear_takes_clear_time_from_work_position() -> void:
	var s := make(ROOM, [["shaper", 3, 2]])
	var u = s.get_unit(1)
	var target := T(4, 2)
	var res := s.command_default_action(1, target)
	eq(res.action, "clear")
	eq(res.stop, T(3, 2), "already on a work position")
	var ticks := run_until(s, func(): return not s.grid.is_blocked(target), 400)
	var expected := int(round(float(s.tuning.clear_time) / s.dt))
	eq(ticks, expected, "clear time in ticks")
	check(u.order == null, "order completes when the tile clears")
	eq(u.status, "idle")
	check(s.grid.is_passable(target), "tile is now passable")


func test_cleared_tile_stays_cleared() -> void:
	var s := make(ROOM, [["shaper", 3, 2]])
	var target := T(4, 2)
	s.command_default_action(1, target)
	run_until(s, func(): return not s.grid.is_blocked(target), 400)
	run(s, 200)
	check(s.grid.is_cleared(target), "cleared permanently")
	var res := s.preview_default_action(1, target)
	eq(res.action, "move", "a cleared tile is a move target")


func test_shaper_walks_to_work_position() -> void:
	var s := make(ROOM, [["shaper", 1, 1]])
	var u = s.get_unit(1)
	var target := T(4, 2)
	s.command_default_action(1, target)
	run_until(s, func(): return u.status == "working", 200)
	eq(Hex.distance(u.tile, target), 1, "working from an adjacent tile")
	check(u.is_settled(), "settled at the work position")
	run_until(s, func(): return not s.grid.is_blocked(target), 400)
	check(s.grid.is_cleared(target))


func test_two_shapers_work_together() -> void:
	var s := make(ROOM, [["shaper", 3, 2], ["shaper", 5, 2]])
	var target := T(4, 2)
	s.command_default_action(1, target)
	s.command_default_action(2, target)
	var ticks := run_until(s, func(): return not s.grid.is_blocked(target), 400)
	var single := int(round(float(s.tuning.clear_time) / s.dt))
	check(ticks > 0 and ticks <= single / 2 + 1, "combined work is faster (%d ticks)" % ticks)
	check(s.get_unit(1).order == null and s.get_unit(2).order == null, "both orders complete")


func test_rejections() -> void:
	var s := make([
		"###########",
		"#...#######",
		"#...##.##.#",
		"#...#######",
		"###########",
	], [["shaper", 1, 2]])
	var deep := s.preview_default_action(1, T(7, 1))
	check(not deep.ok and deep.reason.contains("No work position"), "enclosed tile: %s" % deep.reason)
	var sealed := s.preview_default_action(1, T(4, 2))
	check(sealed.ok, "a tile next to the room can be cleared")
	var pocket := s.preview_default_action(1, T(7, 2))
	check(not pocket.ok and pocket.reason.contains("No route"), "pocket tile: %s" % pocket.reason)
	var outside := s.preview_default_action(1, Vector2i(100, 100))
	check(not outside.ok and outside.reason.contains("Outside"), "outside: %s" % outside.reason)


func test_rejection_keeps_existing_order() -> void:
	var s := make(ROOM, [["shaper", 1, 1]])
	var u = s.get_unit(1)
	s.command_default_action(1, T(7, 3))
	var before = u.order
	var res := s.command_default_action(1, Vector2i(100, 100))
	check(not res.ok, "rejected")
	check(u.order == before, "existing order kept")


func test_core_footprint_rejected() -> void:
	var s := make([
		".........", ".........", ".........", "....C....", ".........", ".........", ".........",
	], [["shaper", 0, 0], ["striker", 8, 6, "assault"]])
	for id in [1, 2]:
		var res := s.preview_default_action(id, s.core_center)
		check(not res.ok and res.reason.contains("Core"), "unit %d: %s" % [id, res.reason])
