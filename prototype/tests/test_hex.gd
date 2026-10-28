extends "res://tests/test_base.gd"


func test_distance_and_neighbors() -> void:
	var o := Vector2i(0, 0)
	eq(Hex.distance(o, o), 0)
	for n in Hex.neighbors(o):
		eq(Hex.distance(o, n), 1, "neighbour distance")
	eq(Hex.distance(Vector2i(0, 0), Vector2i(3, -1)), 3)
	eq(Hex.distance(Vector2i(-2, 1), Vector2i(2, -1)), 4)


func test_offset_roundtrip() -> void:
	for row in range(-3, 6):
		for col in range(-3, 6):
			var a := Hex.offset_to_axial(col, row)
			eq(Hex.axial_to_offset(a), Vector2i(col, row), "roundtrip")
	# Odd rows are shifted right: (0,1) touches (0,0) and (1,0).
	var t := Hex.offset_to_axial(0, 1)
	eq(Hex.distance(t, Hex.offset_to_axial(0, 0)), 1)
	eq(Hex.distance(t, Hex.offset_to_axial(1, 0)), 1)


func test_pixel_roundtrip() -> void:
	for q in range(-4, 5):
		for r in range(-4, 5):
			var t := Vector2i(q, r)
			eq(Hex.from_pixel(Hex.to_pixel(t, 32.0), 32.0), t, "pixel roundtrip")
			eq(Hex.from_pixel(Hex.to_pixel(t, 32.0) + Vector2(10, -8), 32.0), t, "inside hex")


func test_stable_order() -> void:
	var tiles := [Vector2i(2, 1), Vector2i(-1, 1), Vector2i(5, 0), Vector2i(0, -2)]
	eq(Hex.sorted(tiles), [Vector2i(0, -2), Vector2i(5, 0), Vector2i(-1, 1), Vector2i(2, 1)])


func test_line() -> void:
	var l := Hex.line(Vector2i(0, 0), Vector2i(4, -2))
	eq(l.size(), 5)
	eq(l[0], Vector2i(0, 0))
	eq(l[4], Vector2i(4, -2))
	for i in range(1, l.size()):
		eq(Hex.distance(l[i - 1], l[i]), 1, "line contiguous")


func test_direction_from_stick() -> void:
	eq(Hex.direction_from_vector(Vector2(1, 0)), 0, "E")
	eq(Hex.direction_from_vector(Vector2(0.5, -0.86)), 1, "NE")
	eq(Hex.direction_from_vector(Vector2(-0.5, -0.86)), 2, "NW")
	eq(Hex.direction_from_vector(Vector2(-1, 0.05)), 3, "W")
	eq(Hex.direction_from_vector(Vector2(-0.5, 0.86)), 4, "SW")
	eq(Hex.direction_from_vector(Vector2(0.5, 0.86)), 5, "SE")
	# Directions match screen positions of the neighbours.
	for d in range(6):
		var p := Hex.to_pixel(Hex.DIRECTIONS[d], 32.0)
		eq(Hex.direction_from_vector(p), d, "screen direction %d" % d)
