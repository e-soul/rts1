extends SceneTree
## Windowed smoke test of the presentation: loads the main scene, injects input actions
## (the same actions the gamepad triggers), cycles every setup, and fails on any script
## error. Optionally saves screenshots.
##
##   Godot_v4.7.2-stable_win64_console.exe --path prototype --script res://tests/smoke_view.gd -- [screenshot_dir]

var errors := 0
var shot_dir := ""


class ErrorCounter:
	extends Logger
	var owner_tree

	func _log_error(_function: String, _file: String, _line: int, _code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array) -> void:
		if error_type != ERROR_TYPE_WARNING:
			owner_tree.errors += 1
			printerr("smoke: error: ", rationale)

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	var counter := ErrorCounter.new()
	counter.owner_tree = self
	OS.add_logger(counter)
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		shot_dir = args[0]
		DirAccess.make_dir_recursive_absolute(shot_dir)
	_run.call_deferred()


func _press(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _shot(name: String) -> void:
	if shot_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(shot_dir.path_join(name + ".png"))


func _run() -> void:
	var main: Node = load("res://view/main.tscn").instantiate()
	root.add_child(main)
	await _frames(10)
	await _shot("01_sandbox")
	# Select tiles and issue orders with every unit, as A/RB on the gamepad would.
	for i in range(4):
		for d in ["cursor_hex_ne", "cursor_hex_ne", "cursor_hex_nw"]:
			await _press(d)
		await _press("default_action")
		await _press("unit_next")
	await _press("ability")
	await _press("debug_overlay")
	await _press("faster")
	await _press("faster")
	await _press("toggle_spawning")
	await _press("spawn_enemy")
	await _frames(90)
	await _shot("02_orders_debug")
	await _press("pause")
	await _press("step_tick")
	await _press("pause")
	# Camera pan with the right-stick action.
	Input.action_press("camera_right", 1.0)
	Input.action_press("camera_down", 1.0)
	await _frames(120)
	Input.action_release("camera_right")
	Input.action_release("camera_down")
	if main.offscreen_target() == null:
		errors += 1
		printerr("smoke: expected the selected unit offscreen after panning")
	await _shot("03_panned")
	var count: int = main.setup_paths.size()
	for i in range(count):
		await _press("next_setup")
		await _frames(60)
		await _shot("%02d_setup_%s" % [i + 4, main.sim.setup_name.to_snake_case()])
	await _press("reset_setup")
	await _frames(5)
	var ok: bool = errors == 0 and main.sim != null and main.sim.tick_count > 0
	print("smoke: %s (%d errors, %d setups)" % ["ok" if ok else "FAILED", errors, count])
	quit(0 if ok else 1)
