extends CanvasLayer
## Screen-space HUD: selected unit, action preview and rejection messages, controller and
## simulation status, Core HP, banners, help, and the offscreen indicator.

const Hex = preload("res://sim/hex.gd")
const Striker = preload("res://sim/striker.gd")

const HELP := """Gamepad: LB/RB unit  L-stick tile  R-stick camera  A action  B cancel  X form  Menu pause
Keyboard: Q/R unit  W E A D Z X tile  arrows camera  Enter action  Backspace cancel  F form  Space pause
Sandbox: F1 debug  F2 spawning  F3 spawn enemy  F4 invulnerable  F5 reset  F6 next setup
         .  step tick   -/+ speed   H help"""

var unit_info: Label
var status: Label
var action: Label
var message: Label
var banner: Label
var help: Label
var indicator: Control
var _indicator_target = null   # screen position of the selected unit when offscreen
var _indicator_label := ""


func _ready() -> void:
	layer = 10
	unit_info = _label(Vector2(16, 12), 22)
	status = _label(Vector2(0, 12), 20)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	status.offset_left = -900
	status.offset_right = -16
	action = _label(Vector2.ZERO, 26)
	action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	action.offset_left = -900
	action.offset_right = 900
	action.offset_top = -150
	action.offset_bottom = -110
	message = _label(Vector2.ZERO, 24)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	message.grow_vertical = Control.GROW_DIRECTION_BEGIN
	message.offset_left = -800
	message.offset_right = 800
	message.offset_top = -160
	message.offset_bottom = -160
	banner = _label(Vector2.ZERO, 48)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	banner.offset_left = -700
	banner.offset_right = 700
	banner.offset_top = 140
	banner.offset_bottom = 220
	help = _label(Vector2.ZERO, 16)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	help.offset_left = 16
	help.offset_top = -12
	help.offset_bottom = -12
	help.offset_right = 1400
	help.text = HELP.replace("\r", "")
	indicator = Control.new()
	indicator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.draw.connect(_draw_indicator)
	add_child(indicator)


func _label(pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


## Called every frame by main.gd.
func refresh(main) -> void:
	var sim = main.sim
	var u = main.control.selected()
	var lines := PackedStringArray()
	lines.append("Setup: %s  (%d/%d)" % [sim.setup.get("name", sim.setup_name), main.setup_index + 1, main.setup_paths.size()])
	if u == null:
		lines.append("No units")
	else:
		lines.append("%s   HP %d/%d" % [u.label(), ceili(u.hp), int(u.max_hp)])
		var state: String = u.status
		if u.reason != "":
			state += " - " + u.reason
		lines.append("State: " + state)
		if u.order != null and not u.order.implicit:
			lines.append("Order: %s %s" % [u.order.kind.replace("_", "-"), Hex.axial_to_offset(u.order.target)])
		if u.is_changing_form():
			lines.append("Changing form to %s: %d%%" % [Striker.other_form(u.form).capitalize(),
				int(100.0 * Striker.form_change_progress(sim, u))])
	unit_info.text = "\n".join(lines)

	var st := PackedStringArray()
	st.append(main.controller_status)
	var run_state := "PAUSED" if main.paused else "Running"
	st.append("%s  x%s  tick %d" % [run_state, str(main.time_scale()), sim.tick_count])
	if sim.has_core:
		st.append("Core HP %d/%d" % [ceili(sim.core_hp), int(sim.core_max_hp)])
	st.append("Enemies %d   Spawning %s" % [sim.enemy_count(), "on" if sim.spawning_enabled else "off"])
	if sim.invulnerable:
		st.append("INVULNERABLE")
	if main.debug_visible():
		st.append("Opposing-entry ties: %d (%s)" % [sim.opposing_ties, sim.tuning.get("opposing_entry_policy", "")])
	status.text = "\n".join(st)

	var p: Dictionary = main.preview
	if u == null or p.is_empty():
		action.text = ""
	elif p.ok:
		action.text = "A: " + p.text
		action.add_theme_color_override("font_color", Color(0.6, 1.0, 0.65) if p.kind == "goal" else Color(1.0, 0.85, 0.4))
	else:
		action.text = p.reason
		action.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))

	message.text = main.message
	message.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4) if main.message_is_error else Color(0.85, 0.9, 1.0))

	if sim.core_destroyed:
		banner.text = "Core destroyed - F5 to reset"
		banner.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	elif main.paused:
		banner.text = "Paused"
		banner.add_theme_color_override("font_color", Color(1, 1, 1))
	else:
		banner.text = ""
	help.visible = main.show_help

	_indicator_target = main.offscreen_target()
	_indicator_label = u.short_label() + str(u.id) if u != null else ""
	indicator.queue_redraw()


func _draw_indicator() -> void:
	if _indicator_target == null:
		return
	var size := indicator.get_viewport().get_visible_rect().size
	var center := size / 2.0
	var target: Vector2 = _indicator_target
	var margin := 70.0
	var rect := Rect2(Vector2(margin, margin), size - Vector2(margin, margin) * 2.0)
	var dir := (target - center).normalized()
	# Point on the margin rectangle along the direction from the screen centre.
	var tx := INF if dir.x == 0.0 else ((rect.end.x if dir.x > 0.0 else rect.position.x) - center.x) / dir.x
	var ty := INF if dir.y == 0.0 else ((rect.end.y if dir.y > 0.0 else rect.position.y) - center.y) / dir.y
	var p := center + dir * minf(tx, ty)
	var side := dir.orthogonal() * 11.0
	var tri := PackedVector2Array([p + dir * 34.0, p + side, p - dir * 4.0, p - side])
	indicator.draw_colored_polygon(tri, Color(1.0, 0.95, 0.35))
	indicator.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[3], tri[0]]), Color(0, 0, 0), 2.0)
	var font := ThemeDB.fallback_font
	var label: String = _indicator_label
	var lp := p - dir * 26.0 - Vector2(12, -8)
	indicator.draw_string_outline(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color(0, 0, 0))
	indicator.draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.95, 0.35))
