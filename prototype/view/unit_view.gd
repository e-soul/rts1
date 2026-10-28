extends Node2D
## Units interpolated between hex centres, HP bars, form-change progress, shots, and
## clearing progress. Reads simulation state; never changes it.

const Hex = preload("res://sim/hex.gd")
const Unit = preload("res://sim/unit.gd")
const Striker = preload("res://sim/striker.gd")
const Shaper = preload("res://sim/shaper.gd")

const PLAYER := Color(0.35, 0.65, 1.0)
const PLAYER_DARK := Color(0.10, 0.22, 0.45)
const SHAPER_COLOR := Color(0.45, 0.95, 0.55)
const ENEMY := Color(1.0, 0.35, 0.30)
const ENEMY_DARK := Color(0.40, 0.08, 0.06)
const SELECTED := Color(1.0, 0.95, 0.35)
const SHOT_SECONDS := 0.12

var sim
var hex_size := 32.0
var selected_id := -1
## 0..1 between the previous tick and the current tick.
var alpha := 1.0
var _prev: Dictionary = {}   # unit id -> pixel position at the previous tick
var _shots: Array = []       # {from, to, side, ttl}


func set_sim(simulation, size: float) -> void:
	sim = simulation
	hex_size = size
	_prev.clear()
	_shots.clear()


func px(t: Vector2i) -> Vector2:
	return Hex.to_pixel(t, hex_size)


## The unit's position at the current tick.
func tick_position(u) -> Vector2:
	if u.step == null:
		return px(u.tile)
	return px(u.step.from).lerp(px(u.step.to), clampf(u.step.progress, 0.0, 1.0))


## The interpolated position drawn this frame.
func display_position(u) -> Vector2:
	var cur := tick_position(u)
	if _prev.has(u.id):
		return (_prev[u.id] as Vector2).lerp(cur, alpha)
	return cur


## Call before every simulation tick.
func snapshot() -> void:
	_prev.clear()
	for u in sim.units:
		_prev[u.id] = tick_position(u)


func add_shot(e: Dictionary) -> void:
	var from := px(e.from)
	var a = sim.get_unit(e.unit)
	if a != null:
		from = tick_position(a)
	_shots.append({"from": from, "to": px(e.to), "side": e.side, "ttl": SHOT_SECONDS})


func _process(delta: float) -> void:
	for s in _shots:
		s.ttl -= delta
	_shots = _shots.filter(func(s): return s.ttl > 0.0)
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var font := ThemeDB.fallback_font
	# Clearing progress on blocked tiles.
	for t in sim.grid.clear_progress:
		var f := Shaper.clear_progress(sim, t)
		var c := px(t)
		draw_arc(c, hex_size * 0.55, -PI / 2, -PI / 2 + TAU * f, 32, SHAPER_COLOR, 5.0)
	# Core HP.
	if sim.has_core:
		var cc := px(sim.core_center) + Vector2(0, -hex_size * 2.6)
		_bar(cc, hex_size * 3.0, sim.core_hp / sim.core_max_hp, Color(0.4, 0.9, 1.0))
	# Settled units first, then units in transit on top, so overlaps stay readable.
	var order: Array = sim.units.duplicate()
	order.sort_custom(func(a, b): return int(a.in_transit()) < int(b.in_transit()))
	for u in order:
		_draw_unit(u, display_position(u), font)
	for s in _shots:
		var col := PLAYER if s.side == Unit.Side.PLAYER else ENEMY
		col.a = clampf(s.ttl / SHOT_SECONDS, 0.0, 1.0)
		draw_line(s.from, s.to, col, 3.0)
		draw_circle(s.to, 5.0, col)


func _draw_unit(u, p: Vector2, font: Font) -> void:
	var r := hex_size * 0.42
	var transit: bool = u.in_transit()
	if u.id == selected_id:
		draw_arc(p, r + 8.0, 0, TAU, 32, SELECTED, 3.0)
	var body: Color
	var dark: Color
	if not u.is_player():
		body = ENEMY
		dark = ENEMY_DARK
	elif u.kind == Unit.SHAPER:
		body = SHAPER_COLOR
		dark = PLAYER_DARK
	else:
		body = PLAYER
		dark = PLAYER_DARK
	if transit and u.is_player():
		body = body.darkened(0.15)
	match u.kind:
		Unit.STRIKER:
			if u.form == "guard":
				var pts := Hex.corners(p, r * 1.15)
				draw_colored_polygon(pts, body)
				pts.append(pts[0])
				draw_polyline(pts, dark, 3.0)
			else:
				var tri := PackedVector2Array([p + Vector2(0, -r * 1.15), p + Vector2(r, r * 0.8), p + Vector2(-r, r * 0.8)])
				draw_colored_polygon(tri, body)
				tri.append(tri[0])
				draw_polyline(tri, dark, 2.0)
		Unit.SHAPER:
			var dia := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
			draw_colored_polygon(dia, body)
			dia.append(dia[0])
			draw_polyline(dia, dark, 2.0)
		_:
			draw_circle(p, r * 0.85, body)
			draw_arc(p, r * 0.85, 0, TAU, 24, dark, 2.0)
	if transit:
		# Dashed ring: in transit (overlapping a friendly or between tiles).
		for i in range(8):
			var a0 := TAU * i / 8.0
			draw_arc(p, r + 3.0, a0, a0 + TAU / 16.0, 4, Color(1, 1, 1, 0.7), 2.0)
	if u.is_player():
		draw_string(font, p + Vector2(-4, 6), u.short_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, dark)
	if u.hp < u.max_hp:
		_bar(p + Vector2(0, -r - 10.0), hex_size * 0.9, u.hp / u.max_hp, body)
	if u.is_changing_form():
		var f := Striker.form_change_progress(sim, u)
		draw_arc(p, r + 13.0, -PI / 2, -PI / 2 + TAU * f, 32, SELECTED, 4.0)
	match u.status:
		"blocked":
			draw_string(font, p + Vector2(r * 0.7, -r * 0.6), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.4, 0.2))
		"holding":
			draw_string(font, p + Vector2(r * 0.7, -r * 0.6), "H", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.9, 0.4))


func _bar(center: Vector2, width: float, fraction: float, color: Color) -> void:
	var tl := center - Vector2(width / 2.0, 3.0)
	draw_rect(Rect2(tl, Vector2(width, 6.0)), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(tl, Vector2(width * clampf(fraction, 0.0, 1.0), 6.0)), color)
