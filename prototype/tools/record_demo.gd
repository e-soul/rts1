extends SceneTree
## Scripted demo of the movement and gamepad control rules for sharing as a video. Loads
## the sandbox, injects the same InputMap actions the gamepad produces (stick vectors go
## through the real sector snapping and repeat logic), and overlays captions plus a
## virtual gamepad so viewers can see what is being pressed. Run under Movie Maker mode
## to record it:
##
##   Godot_v4.7.2-stable_win64_console.exe --path prototype --script res://tools/record_demo.gd
##       --write-movie <dir>/demo.png --fixed-fps 60
##
## Without --write-movie it simply plays the demo in a window and quits.

const Hex = preload("res://sim/hex.gd")

const FPS := 60.0
const CAMERA_ZOOM := 1.5   # closer than the sandbox default so the hexes read on a phone
const STICK_ANGLES_DEG := [0.0, -60.0, -120.0, 180.0, 120.0, 60.0]   # Hex direction order

var main: Node
var caption: Label
var pad: Control
var left_stick := Vector2.ZERO
var right_stick := Vector2.ZERO
var pressed: Dictionary = {}
var elapsed := 0.0


func _initialize() -> void:
	_run.call_deferred()


# --- Input injection (same actions as the physical gamepad) -------------------------

func _press(action: String) -> void:
	pressed[action] = true
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await _seconds(0.12)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	pressed.erase(action)
	await process_frame


func _set_axis(neg: String, pos: String, value: float) -> void:
	if value > 0.0:
		Input.action_release(neg)
		Input.action_press(pos, value)
	elif value < 0.0:
		Input.action_release(pos)
		Input.action_press(neg, -value)
	else:
		Input.action_release(neg)
		Input.action_release(pos)


func _left_stick(v: Vector2) -> void:
	left_stick = v
	_set_axis("cursor_left", "cursor_right", v.x)
	_set_axis("cursor_up", "cursor_down", v.y)


func _right_stick(v: Vector2) -> void:
	right_stick = v
	_set_axis("camera_left", "camera_right", v.x)
	_set_axis("camera_up", "camera_down", v.y)


## Holds the left stick in a hex direction until the cursor has moved `steps` hexes.
func _stick_steps(dir: int, steps: int) -> void:
	var a := deg_to_rad(STICK_ANGLES_DEG[dir])
	_left_stick(Vector2(cos(a), sin(a)))
	var moved := 0
	var last: Vector2i = main.control.cursor
	var guard := 0
	while moved < steps and guard < 600:
		await process_frame
		guard += 1
		if main.control.cursor != last:
			last = main.control.cursor
			moved += 1
	_left_stick(Vector2.ZERO)
	await process_frame


func _pan(v: Vector2, seconds: float) -> void:
	_right_stick(v)
	await _seconds(seconds)
	_right_stick(Vector2.ZERO)


## Pans south until the camera is back at `y` (the outward pan gets clamped at the map edge,
## so a timed return would overshoot).
func _pan_back_down_to(y: float) -> void:
	_right_stick(Vector2(0, 1))
	var guard := 0
	while main.camera.position.y < y and guard < 300:
		await process_frame
		guard += 1
	_right_stick(Vector2.ZERO)


func _seconds(s: float) -> void:
	for i in range(int(round(s * FPS))):
		await process_frame


# --- Overlay ------------------------------------------------------------------------

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	root.add_child(layer)

	# One short line, pinned to the top edge between the HUD's unit info and status blocks.
	caption = Label.new()
	caption.add_theme_font_size_override("font_size", 38)
	caption.add_theme_color_override("font_color", Color(1, 1, 1))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.07, 0.12, 0.85)
	box.set_corner_radius_all(10)
	box.content_margin_left = 28
	box.content_margin_right = 28
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	caption.add_theme_stylebox_override("normal", box)
	caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	caption.offset_left = -520
	caption.offset_right = 520
	caption.offset_top = 10
	caption.offset_bottom = 10
	caption.grow_vertical = Control.GROW_DIRECTION_END
	caption.visible = false
	layer.add_child(caption)

	pad = Control.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	pad.offset_left = -400
	pad.offset_top = -270
	pad.offset_right = -16
	pad.offset_bottom = -16
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.draw.connect(_draw_pad)
	layer.add_child(pad)
	process_frame.connect(func() -> void:
		elapsed += 1.0 / FPS
		pad.queue_redraw())


func _say(text: String) -> void:
	caption.text = text
	caption.visible = text != ""


func _draw_pad() -> void:
	var font := ThemeDB.fallback_font
	var size := pad.size
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.07, 0.12, 0.82)
	bg.set_corner_radius_all(14)
	pad.draw_style_box(bg, Rect2(Vector2.ZERO, size))
	var dim := Color(0.55, 0.6, 0.7)
	var lit := Color(1.0, 0.85, 0.3)
	_draw_button(Rect2(28, 16, 78, 30), "LB", pressed.has("unit_prev"), dim, lit, font)
	_draw_button(Rect2(size.x - 106, 16, 78, 30), "RB", pressed.has("unit_next"), dim, lit, font)
	_draw_button(Rect2(size.x / 2.0 - 36, 20, 72, 24), "Menu", pressed.has("pause"), dim, lit, font)
	_draw_stick(Vector2(84, 124), left_stick, "L: tile", dim, lit, font)
	_draw_stick(Vector2(size.x / 2.0 + 10, 166), right_stick, "R: camera", dim, lit, font)
	var c := Vector2(size.x - 84, 116)
	var r := 20.0
	_draw_face(c + Vector2(0, 34), "A", pressed.has("default_action"), Color(0.35, 0.75, 0.35), lit, r, font)
	_draw_face(c + Vector2(34, 0), "B", pressed.has("cancel"), Color(0.8, 0.3, 0.3), lit, r, font)
	_draw_face(c + Vector2(-34, 0), "X", pressed.has("ability"), Color(0.3, 0.5, 0.9), lit, r, font)
	_draw_face(c + Vector2(0, -34), "Y", false, Color(0.75, 0.65, 0.2), lit, r, font)
	pad.draw_string(font, Vector2(14, size.y - 12), "Scripted gamepad input", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, dim)


func _draw_button(rect: Rect2, label: String, on: bool, dim: Color, lit: Color, font: Font) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = lit if on else Color(0.2, 0.22, 0.3)
	sb.set_corner_radius_all(6)
	pad.draw_style_box(sb, rect)
	var col := Color(0.1, 0.1, 0.1) if on else dim
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	pad.draw_string(font, rect.position + Vector2((rect.size.x - w) / 2.0, rect.size.y / 2.0 + 6), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)


func _draw_stick(center: Vector2, v: Vector2, label: String, dim: Color, lit: Color, font: Font) -> void:
	var on := v != Vector2.ZERO
	pad.draw_circle(center, 40.0, Color(0.2, 0.22, 0.3))
	pad.draw_arc(center, 40.0, 0.0, TAU, 48, lit if on else dim, 2.0)
	if on:
		pad.draw_line(center, center + v * 22.0, lit, 3.0)
	pad.draw_circle(center + v * 22.0, 15.0, lit if on else Color(0.45, 0.5, 0.6))
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	pad.draw_string(font, center + Vector2(-w / 2.0, 62.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, lit if on else dim)


func _draw_face(center: Vector2, label: String, on: bool, base: Color, lit: Color, r: float, font: Font) -> void:
	pad.draw_circle(center, r + (4.0 if on else 0.0), lit if on else base.darkened(0.45))
	pad.draw_arc(center, r, 0.0, TAU, 32, lit if on else base, 2.0)
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	pad.draw_string(font, center + Vector2(-w / 2.0, 7.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
		Color(0.1, 0.1, 0.1) if on else Color(1, 1, 1))


# --- The demo -----------------------------------------------------------------------

func _run() -> void:
	main = load("res://view/main.tscn").instantiate()
	root.add_child(main)
	_build_overlay()
	await process_frame
	main.controller_status = "Scripted gamepad input"
	main.message = ""
	main.camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	main._clamp_camera()
	main.camera.reset_smoothing()
	await _seconds(0.5)

	_say("Rules prototype: movement and gamepad controls")
	await _seconds(2.5)

	# Left stick: the selected tile. The cursor starts on the Core centre (34, 22).
	_say("Left stick: move the selected tile")
	await _seconds(0.7)
	await _stick_steps(Hex.E, 3)            # -> (37, 22)
	await _seconds(0.5)
	await _stick_steps(Hex.NE, 1)           # -> (37, 21)
	await _seconds(1.0)

	_say("A: send the selected unit there")
	await _seconds(1.3)
	await _press("default_action")          # Assault Striker attack-moves
	await _seconds(1.6)

	_say("RB / LB: switch unit, the tile stays")
	await _press("unit_next")               # Guard Striker
	await _seconds(1.7)

	_say("Taken destination: stops at the nearest free hex")
	await _seconds(1.3)
	await _press("default_action")
	await _seconds(1.7)

	_say("Same controls for every unit")
	await _press("unit_next")               # Shaper
	await _seconds(0.6)
	await _stick_steps(Hex.SW, 3)           # -> (36, 24)
	await _seconds(1.0)
	await _press("default_action")          # Shaper moves
	await _seconds(1.8)

	_say("Right stick: pan the camera")
	await _seconds(0.5)
	var home_y: float = main.camera.position.y
	await _pan(Vector2(0, -1), 1.0)         # north, toward the spawn pocket and corridor
	await _seconds(1.0)
	await _pan_back_down_to(home_y)
	await _seconds(0.8)

	_say("Feedback on movement and controls welcome")
	await _seconds(2.4)
	_say("")
	await _seconds(0.3)
	print("demo: finished after %.1f s" % elapsed)
	quit(0)
