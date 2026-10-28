extends Node2D
## The selected tile and the default-action preview: planned route and stopping position.

const Hex = preload("res://sim/hex.gd")

const CURSOR := Color(1.0, 0.95, 0.35)
const GOOD := Color(0.45, 1.0, 0.55)
const ALTERNATIVE := Color(1.0, 0.8, 0.3)
const BLOCKED := Color(1.0, 0.5, 0.2)
const INVALID := Color(1.0, 0.3, 0.3)

var sim
var unit_view
var hex_size := 32.0
var cursor := Vector2i.ZERO
var preview: Dictionary = {}
var selected_id := -1
var _time := 0.0


func set_sim(simulation, size: float, units) -> void:
	sim = simulation
	hex_size = size
	unit_view = units


func px(t: Vector2i) -> Vector2:
	return Hex.to_pixel(t, hex_size)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


static func kind_color(kind: String) -> Color:
	match kind:
		"goal":
			return GOOD
		"alternative", "work_pending":
			return ALTERNATIVE
	return BLOCKED


func _draw() -> void:
	if sim == null:
		return
	var u = sim.get_unit(selected_id)
	# The selected unit's current order: target and planned stop, dimmed.
	if u != null and u.order != null and not u.order.implicit:
		_hex_outline(u.order.target, Color(1, 1, 1, 0.35), 2.0, 0.8)
	var pulse := 0.5 + 0.5 * sin(_time * 6.0)
	if not preview.is_empty() and u != null:
		if preview.ok:
			var col := kind_color(preview.kind)
			var route: Array = preview.route
			if route.size() > 1:
				var pts := PackedVector2Array([unit_view.display_position(u)])
				for i in range(1, route.size()):
					pts.append(px(route[i]))
				draw_polyline(pts, Color(col, 0.75), 4.0)
			if preview.stop != null:
				draw_circle(px(preview.stop), hex_size * 0.25, Color(col, 0.8))
			if preview.stop != null and preview.stop != cursor:
				draw_dashed_line(px(preview.stop), px(cursor), Color(col, 0.6), 2.0, 6.0)
		else:
			var c := px(cursor)
			var d := hex_size * 0.35
			draw_line(c + Vector2(-d, -d), c + Vector2(d, d), INVALID, 4.0)
			draw_line(c + Vector2(-d, d), c + Vector2(d, -d), INVALID, 4.0)
	_hex_outline(cursor, Color(CURSOR, 0.7 + 0.3 * pulse), 4.0, 1.0)


func _hex_outline(t: Vector2i, col: Color, width: float, scale_factor: float) -> void:
	var pts := Hex.corners(px(t), (hex_size - 2.0) * scale_factor)
	pts.append(pts[0])
	draw_polyline(pts, col, width)
