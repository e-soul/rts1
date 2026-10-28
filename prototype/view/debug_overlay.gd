extends Node2D
## F1 debug overlay: stopping claims coloured by owner, entering steps, planned routes,
## alternative destinations, and per-unit state labels.

const Hex = preload("res://sim/hex.gd")
const Occupancy = preload("res://sim/occupancy.gd")

var sim
var unit_view
var hex_size := 32.0


func set_sim(simulation, size: float, units) -> void:
	sim = simulation
	hex_size = size
	unit_view = units


func px(t: Vector2i) -> Vector2:
	return Hex.to_pixel(t, hex_size)


static func owner_color(id: int) -> Color:
	return Color.from_hsv(fmod(id * 0.618034, 1.0), 0.75, 1.0)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var font := ThemeDB.fallback_font
	var claims: Dictionary = sim.occupancy.claims[Occupancy.GROUND]
	for t in claims:
		var col := owner_color(claims[t])
		draw_colored_polygon(Hex.corners(px(t), hex_size * 0.8), Color(col, 0.22))
		var pts := Hex.corners(px(t), hex_size * 0.8)
		pts.append(pts[0])
		draw_polyline(pts, Color(col, 0.9), 2.0)
		draw_string(font, px(t) + Vector2(-hex_size * 0.6, hex_size * 0.55), str(claims[t]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
	for u in sim.units:
		var col := owner_color(u.id)
		var p: Vector2 = unit_view.display_position(u)
		if u.step != null and not u.step.returning:
			# Tile being entered: blocks hostile entry (section 3).
			draw_arc(px(u.step.to), hex_size * 0.45, 0, TAU, 16, Color(col, 0.8), 1.5)
		if u.route.size() > 1:
			var pts := PackedVector2Array([p])
			for i in range(1, u.route.size()):
				pts.append(px(u.route[i]))
			draw_polyline(pts, Color(col, 0.5), 2.0)
		if u.planned_stop != null and u.alternative:
			var s := px(u.planned_stop)
			draw_rect(Rect2(s - Vector2(7, 7), Vector2(14, 14)), Color(col, 0.9), false, 2.0)
			if u.order != null:
				draw_dashed_line(s, px(u.order.target), Color(col, 0.5), 1.5, 5.0)
		var lines := PackedStringArray(["#%d %s" % [u.id, u.status]])
		if u.order != null:
			lines.append("%s%s %s" % [u.order.kind, " (implicit)" if u.order.implicit else "",
				Hex.axial_to_offset(u.order.target)])
		if u.step != null:
			lines.append("step %s%s %.2f" % [Hex.axial_to_offset(u.step.to),
				" ret" if u.step.returning else "", u.step.progress])
		elif u.in_transit():
			lines.append("transit")
		if u.reason != "":
			lines.append(u.reason)
		var y := hex_size * 0.75
		for line in lines:
			draw_string_outline(font, p + Vector2(-hex_size * 0.9, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.85))
			draw_string(font, p + Vector2(-hex_size * 0.9, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.95))
			y += 14.0
