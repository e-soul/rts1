extends Node2D
## Sandbox root: owns the simulation, advances it on a fixed tick, routes input to the
## control model, and drives the views. No rules live here.

const Sim = preload("res://sim/simulation.gd")
const Hex = preload("res://sim/hex.gd")
const PlayerControl = preload("res://sim/control.gd")
const Bindings = preload("res://input/bindings.gd")
const GamepadInput = preload("res://input/gamepad_input.gd")
const MapView = preload("res://view/map_view.gd")
const UnitView = preload("res://view/unit_view.gd")
const CursorView = preload("res://view/cursor_view.gd")
const DebugOverlay = preload("res://view/debug_overlay.gd")
const Hud = preload("res://view/hud.gd")

const TIME_SCALES := [0.25, 0.5, 1.0, 2.0, 4.0]
const MAX_TICKS_PER_FRAME := 8

var sim
var control
var gamepad := GamepadInput.new()
var setup_paths: Array[String] = []
var setup_index := 0
var paused := false
var time_scale_index := 2
var accumulator := 0.0
var hex_size := 32.0
var map_rect := Rect2()
var preview: Dictionary = {}
var message := ""
var message_is_error := false
var message_left := 0.0
var show_help := true
var controller_status := ""

var camera: Camera2D
var map_view
var unit_view
var cursor_view
var debug_overlay
var hud
var _preview_key: Array = []


func _ready() -> void:
	Bindings.register()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	controller_status = GamepadInput.controller_status()
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	map_view = MapView.new()
	unit_view = UnitView.new()
	cursor_view = CursorView.new()
	debug_overlay = DebugOverlay.new()
	debug_overlay.visible = false
	add_child(map_view)
	add_child(cursor_view)
	add_child(unit_view)
	add_child(debug_overlay)
	hud = Hud.new()
	add_child(hud)
	setup_paths = Sim.list_setups()
	var start := 0
	for i in range(setup_paths.size()):
		if setup_paths[i].get_file() == "sandbox.json":
			start = i
	load_setup(start)


func load_setup(index: int) -> void:
	setup_index = posmod(index, setup_paths.size())
	# Tuning is reloaded on every reset so numbers can be edited between runs.
	sim = Sim.from_file(setup_paths[setup_index], Sim.load_tuning())
	control = PlayerControl.new(sim)
	hex_size = float(sim.tuning.hex_size)
	gamepad.configure(sim.tuning.get("input", {}))
	accumulator = 0.0
	_preview_key = []
	map_rect = Rect2()
	for t in sim.grid.tiles:
		var p := Hex.to_pixel(t, hex_size)
		var r := Rect2(p - Vector2(hex_size, hex_size), Vector2(hex_size, hex_size) * 2.0)
		map_rect = r if map_rect.size == Vector2.ZERO else map_rect.merge(r)
	map_view.set_sim(sim, hex_size)
	unit_view.set_sim(sim, hex_size)
	cursor_view.set_sim(sim, hex_size, unit_view)
	debug_overlay.set_sim(sim, hex_size, unit_view)
	camera.position = Hex.to_pixel(sim.camera_start, hex_size)
	_clamp_camera()
	camera.reset_smoothing()
	var desc: String = sim.setup.get("description", "")
	var title: String = sim.setup.get("name", sim.setup_name)
	flash("%s%s" % [title, (": " + desc) if desc != "" else ""], false, 6.0)


func time_scale() -> float:
	return TIME_SCALES[time_scale_index]


func debug_visible() -> bool:
	return debug_overlay.visible


func flash(text: String, is_error: bool = false, seconds: float = -1.0) -> void:
	message = text
	message_is_error = is_error
	if seconds < 0.0:
		seconds = float(sim.tuning.get("input", {}).get("rejection_message_seconds", 2.5))
	message_left = seconds


# --- Simulation ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if paused or sim.core_destroyed:
		return
	accumulator += delta * time_scale()
	var n := 0
	while accumulator >= sim.dt and n < MAX_TICKS_PER_FRAME:
		_tick()
		accumulator -= sim.dt
		n += 1
	if n == MAX_TICKS_PER_FRAME:
		accumulator = minf(accumulator, sim.dt)


func _tick() -> void:
	unit_view.snapshot()
	sim.tick()
	for e in sim.take_events():
		match e.type:
			"shot":
				unit_view.add_shot(e)
			"core_destroyed":
				flash("Core destroyed", true, 5.0)
	control.ensure_selection()


# --- Input --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("unit_next"):
		control.select_next()
	elif event.is_action_pressed("unit_prev"):
		control.select_prev()
	elif event.is_action_pressed("default_action"):
		var r: Dictionary = control.default_action()
		if not r.ok:
			flash(r.reason, true)
	elif event.is_action_pressed("ability"):
		var r: Dictionary = control.ability()
		if not r.ok:
			flash(r.reason, true)
	elif event.is_action_pressed("cancel"):
		var r: Dictionary = control.cancel()
		if not r.ok:
			flash(r.reason)
	elif event.is_action_pressed("pause"):
		paused = not paused
	elif event.is_action_pressed("step_tick"):
		if paused and not sim.core_destroyed:
			_tick()
	elif event.is_action_pressed("slower"):
		time_scale_index = maxi(0, time_scale_index - 1)
		flash("Speed x%s" % str(time_scale()))
	elif event.is_action_pressed("faster"):
		time_scale_index = mini(TIME_SCALES.size() - 1, time_scale_index + 1)
		flash("Speed x%s" % str(time_scale()))
	elif event.is_action_pressed("debug_overlay"):
		debug_overlay.visible = not debug_overlay.visible
	elif event.is_action_pressed("toggle_spawning"):
		sim.spawning_enabled = not sim.spawning_enabled
		flash("Enemy spawning %s" % ("on" if sim.spawning_enabled else "off"))
	elif event.is_action_pressed("spawn_enemy"):
		var e = sim.spawn_enemy_near(control.cursor)
		flash("Enemy spawned" if e != null else "No free spawn position", e == null)
	elif event.is_action_pressed("toggle_invulnerable"):
		sim.invulnerable = not sim.invulnerable
		flash("Invulnerability %s" % ("on" if sim.invulnerable else "off"))
	elif event.is_action_pressed("reset_setup"):
		load_setup(setup_index)
	elif event.is_action_pressed("next_setup"):
		load_setup(setup_index + 1)
	elif event.is_action_pressed("toggle_help"):
		show_help = not show_help
	else:
		return
	get_viewport().set_input_as_handled()


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	controller_status = GamepadInput.controller_status()
	flash("Controller %d %s" % [device, "connected" if connected else "disconnected"], not connected)


# --- Per frame ----------------------------------------------------------------------

func _process(delta: float) -> void:
	var cam_input: Vector2 = gamepad.camera_vector()
	if cam_input != Vector2.ZERO:
		camera.position += cam_input * float(sim.tuning.input.get("camera_pan_speed", 1400.0)) * delta
		_clamp_camera()
		if sim.tuning.input.get("cursor_follow_camera", true):
			_keep_cursor_in_view()
	var dir: int = gamepad.cursor_step(delta)
	if dir != -1 and control.move_cursor(dir):
		_keep_camera_on_cursor()

	control.ensure_selection()
	_update_preview()
	if message_left > 0.0:
		message_left -= delta
		if message_left <= 0.0:
			message = ""

	unit_view.alpha = 1.0 if paused else clampf(accumulator / sim.dt, 0.0, 1.0)
	unit_view.selected_id = control.selected_id
	cursor_view.selected_id = control.selected_id
	cursor_view.cursor = control.cursor
	cursor_view.preview = preview
	hud.refresh(self)


func _update_preview() -> void:
	var key := [control.selected_id, control.cursor, sim.tick_count, sim.grid.version]
	if key == _preview_key:
		return
	_preview_key = key
	preview = control.preview() if control.selected() != null else {}


# --- Camera -------------------------------------------------------------------------

func _view_size() -> Vector2:
	return get_viewport_rect().size / camera.zoom


func _view_rect() -> Rect2:
	var size := _view_size()
	return Rect2(camera.position - size / 2.0, size)


func _clamp_camera() -> void:
	var half := _view_size() / 2.0
	var p := camera.position
	if map_rect.size.x <= half.x * 2.0:
		p.x = map_rect.get_center().x
	else:
		p.x = clampf(p.x, map_rect.position.x + half.x, map_rect.end.x - half.x)
	if map_rect.size.y <= half.y * 2.0:
		p.y = map_rect.get_center().y
	else:
		p.y = clampf(p.y, map_rect.position.y + half.y, map_rect.end.y - half.y)
	camera.position = p


## Cursor follows the camera edge so it never leaves the screen.
func _keep_cursor_in_view() -> void:
	var inner := _view_rect().grow(-hex_size * 1.5)
	var c := Hex.to_pixel(control.cursor, hex_size)
	if inner.has_point(c):
		return
	var clamped := Vector2(clampf(c.x, inner.position.x, inner.end.x), clampf(c.y, inner.position.y, inner.end.y))
	var t := Hex.from_pixel(clamped, hex_size)
	if sim.grid.in_map(t):
		control.set_cursor(t)


## Camera scrolls to keep a stick-moved cursor visible.
func _keep_camera_on_cursor() -> void:
	var inner := _view_rect().grow(-hex_size * 2.5)
	var c := Hex.to_pixel(control.cursor, hex_size)
	var shift := Vector2.ZERO
	if c.x < inner.position.x:
		shift.x = c.x - inner.position.x
	elif c.x > inner.end.x:
		shift.x = c.x - inner.end.x
	if c.y < inner.position.y:
		shift.y = c.y - inner.position.y
	elif c.y > inner.end.y:
		shift.y = c.y - inner.end.y
	if shift != Vector2.ZERO:
		camera.position += shift
		_clamp_camera()


## Screen position of the selected unit if it is offscreen, else null.
func offscreen_target() -> Variant:
	var u = control.selected()
	if u == null:
		return null
	var screen: Vector2 = get_viewport().get_canvas_transform() * unit_view.display_position(u)
	var rect := get_viewport_rect().grow(-hex_size * 0.5)
	return null if rect.has_point(screen) else screen
