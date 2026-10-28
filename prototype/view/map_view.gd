extends Node2D
## Terrain, Core footprint, and spawn points. Redrawn only when the terrain changes.

const Hex = preload("res://sim/hex.gd")

const CLEARED := Color(0.20, 0.24, 0.20)
const CLEARED_EDGE := Color(0.28, 0.33, 0.27)
const BLOCKED := Color(0.33, 0.27, 0.21)
const BLOCKED_EDGE := Color(0.24, 0.19, 0.15)
const CORE := Color(0.16, 0.42, 0.50)
const CORE_EDGE := Color(0.35, 0.80, 0.90)
const SPAWN := Color(0.45, 0.14, 0.14)

var sim
var hex_size := 32.0
var _drawn_version := -1


func set_sim(simulation, size: float) -> void:
	sim = simulation
	hex_size = size
	_drawn_version = -1
	queue_redraw()


func _process(_delta: float) -> void:
	if sim != null and sim.grid.version != _drawn_version:
		queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	_drawn_version = sim.grid.version
	var grid = sim.grid
	var spawns := {}
	for sp in sim.spawn_points:
		spawns[sp] = true
	for t in grid.tiles:
		var c := Hex.to_pixel(t, hex_size)
		var pts := Hex.corners(c, hex_size - 1.0)
		var fill := CLEARED
		var edge := CLEARED_EDGE
		if grid.footprint.has(t):
			fill = CORE
			edge = CORE_EDGE
		elif grid.is_blocked(t):
			fill = BLOCKED
			edge = BLOCKED_EDGE
		elif spawns.has(t):
			fill = SPAWN
		draw_colored_polygon(pts, fill)
		pts.append(pts[0])
		draw_polyline(pts, edge, 1.0)
		if grid.is_blocked(t):
			# Rocky texture marks: blocked terrain must read differently at a glance.
			draw_line(c + Vector2(-8, -4), c + Vector2(6, 6), BLOCKED_EDGE, 2.0)
			draw_line(c + Vector2(2, -10), c + Vector2(10, -2), BLOCKED_EDGE, 2.0)
	if sim.has_core:
		var cc := Hex.to_pixel(sim.core_center, hex_size)
		draw_circle(cc, hex_size * 1.1, CORE_EDGE)
		draw_circle(cc, hex_size * 0.8, CORE)
	var font := ThemeDB.fallback_font
	for sp in sim.spawn_points:
		var p := Hex.to_pixel(sp, hex_size)
		draw_string(font, p + Vector2(-6, 7), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.5, 0.5, 0.8))
