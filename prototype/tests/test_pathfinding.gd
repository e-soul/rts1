extends "res://tests/test_base.gd"

const Pathfinding = preload("res://sim/pathfinding.gd")
const Movement = preload("res://sim/movement.gd")


func test_route_around_obstacle() -> void:
	var s := make([
		".......",
		"...#...",
		"...#...",
		"...#...",
		".......",
	])
	var r := Pathfinding.find_route(s.grid, T(1, 2), T(5, 2))
	check(r.size() > 0, "route exists")
	eq(r[0], T(1, 2))
	eq(r[r.size() - 1], T(5, 2))
	for i in range(1, r.size()):
		eq(Hex.distance(r[i - 1], r[i]), 1, "contiguous")
		check(s.grid.is_passable(r[i]), "passable")
	# Same inputs, same route.
	eq(Pathfinding.find_route(s.grid, T(1, 2), T(5, 2)), r, "deterministic")


func test_unreachable() -> void:
	var s := make([
		"...#...",
		"...#...",
		"...#...",
	])
	eq(Pathfinding.find_route(s.grid, T(0, 1), T(6, 1)).size(), 0)
	check(not s.grid.terrain_reachable(T(0, 1), T(6, 1)), "terrain unreachable")


func test_core_footprint_impassable() -> void:
	var s := make([
		".......",
		".......",
		"...C...",
		".......",
		".......",
	])
	eq(s.core_tiles.size(), 7)
	for t in s.core_tiles:
		check(not s.grid.is_passable(t), "footprint impassable")
	var r := Pathfinding.find_route(s.grid, T(0, 2), T(6, 2))
	for t in r:
		check(not s.grid.footprint.has(t), "route avoids footprint")
	eq(s.grid.adjacent_positions(s.core_center).size(), 12, "ring around core")


func test_alternative_prefers_walk_distance_then_route_then_order() -> void:
	# Target T(3,2) is claimed by a settled unit. The mover at T(0,2) should pick a free
	# neighbour of the target (walk distance 1), the one closest to itself (route), and
	# among equals, the first in stable tile order.
	var s := make(field(7, 5), [["striker", 3, 2], ["striker", 0, 2]])
	var mover = s.get_unit(2)
	var choice := Movement.choose_stop(s, mover, Unit.Order.new("move", T(3, 2)), {})
	eq(choice.kind, "alternative")
	eq(choice.stop, T(2, 2), "west neighbour is closest to the mover")
	# Mover directly north of target, equidistant to two neighbours: stable order (r, q).
	var s2 := make(field(7, 5), [["striker", 3, 2], ["striker", 3, 0]])
	var m2 = s2.get_unit(2)
	var c2 := Movement.choose_stop(s2, m2, Unit.Order.new("move", T(3, 2)), {})
	eq(c2.kind, "alternative")
	eq(Hex.distance(c2.stop, T(3, 2)), 1, "adjacent to target")
	var rl: Dictionary = c2.search.dist
	for n in Hex.neighbors(T(3, 2)):
		if n != c2.stop and rl.has(n):
			check(rl[n] > rl[c2.stop] or (rl[n] == rl[c2.stop] and Hex.less(c2.stop, n)), "tie broken by route then order")


func test_alternative_uses_walking_not_straight_distance() -> void:
	# Wall between: the tile just across the wall is close in a straight line but far to walk.
	var s := make([
		".......",
		".#####.",
		".......",
	], [["striker", 3, 2], ["striker", 3, 0]])
	var m = s.get_unit(2)
	var c := Movement.choose_stop(s, m, Unit.Order.new("move", T(3, 2)), {})
	eq(c.kind, "alternative")
	check(c.stop.y == 2, "chosen tile is on the target's side of the wall, got %s" % c.stop)
