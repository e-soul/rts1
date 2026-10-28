extends SceneTree
## Minimal headless test runner. Runs every test_* method in the test scripts below,
## fails a test on any assertion failure or script/engine error, and exits non-zero on
## failure.
##   Godot_v4.7.2-stable_win64_console.exe --headless --path prototype --script res://tests/run_tests.gd
## Optional filter: append `-- <substring>` to run only matching tests.

const TEST_SCRIPTS := [
	"res://tests/test_hex.gd",
	"res://tests/test_pathfinding.gd",
	"res://tests/test_movement.gd",
	"res://tests/test_cancellation.gd",
	"res://tests/test_enemy_blocking.gd",
	"res://tests/test_combat.gd",
	"res://tests/test_shaper.gd",
	"res://tests/test_control.gd",
	"res://tests/test_scenarios.gd",
]


class ErrorCounter:
	extends Logger
	var count := 0
	var last := ""

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		count += 1
		last = "%s (%s:%d %s) %s" % [code, file, line, function, rationale]

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]
	var counter := ErrorCounter.new()
	OS.add_logger(counter)
	var passed := 0
	var failed: Array[String] = []
	for path in TEST_SCRIPTS:
		var script: GDScript = load(path)
		if script == null:
			failed.append("%s: failed to load" % path)
			continue
		for m in script.get_script_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			var full := "%s::%s" % [path.get_file().get_basename(), name]
			if filter != "" and not full.contains(filter):
				continue
			var t = script.new()
			t.current = full
			var errors_before := counter.count
			t.call(name)
			var problems: Array[String] = t.failures.duplicate()
			if counter.count != errors_before:
				problems.append("%s: script/engine error: %s" % [full, counter.last])
			if problems.is_empty():
				passed += 1
			else:
				failed.append_array(problems)
				print("FAIL ", full)
				for p in problems:
					print("    ", p)
	print("")
	print("%d passed, %d failing checks" % [passed, failed.size()])
	OS.remove_logger(counter)
	quit(0 if failed.is_empty() else 1)
