extends RefCounted
## Translates stick state into hex cursor steps and camera motion. Buttons are handled as
## InputMap action events by main.gd. Everything is read through actions (bindings.gd).

const Hex = preload("res://sim/hex.gd")
const Bindings = preload("res://input/bindings.gd")

## Extra angle beyond the 30-degree sector half-width before a held direction changes,
## so a stick resting near a sector boundary does not flicker between directions.
const SECTOR_HYSTERESIS_DEG := 8.0
const DIRECTION_ANGLES_DEG := [0.0, -60.0, -120.0, 180.0, 120.0, 60.0]

var stick_deadzone := 0.5
var camera_deadzone := 0.2
var initial_delay := 0.3
var repeat_interval := 0.09

var _held_dir := -1
var _timer := 0.0


func configure(input_tuning: Dictionary) -> void:
	stick_deadzone = float(input_tuning.get("stick_deadzone", stick_deadzone))
	camera_deadzone = float(input_tuning.get("camera_deadzone", camera_deadzone))
	initial_delay = float(input_tuning.get("cursor_initial_delay", initial_delay))
	repeat_interval = float(input_tuning.get("cursor_repeat", repeat_interval))


## The hex direction currently held (stick first, then keyboard), or -1.
func held_direction() -> int:
	var v := Input.get_vector("cursor_left", "cursor_right", "cursor_up", "cursor_down", stick_deadzone)
	if v != Vector2.ZERO:
		if _held_dir != -1 and _within_sector(v, _held_dir, 30.0 + SECTOR_HYSTERESIS_DEG):
			return _held_dir
		return Hex.direction_from_vector(v)
	for i in range(Bindings.HEX_ACTIONS.size()):
		if Input.is_action_pressed(Bindings.HEX_ACTIONS[i]):
			return i
	return -1


## Cursor steps to apply this frame: a direction index, or -1. Steps immediately when a
## direction is first held, then repeats after the initial delay.
func cursor_step(delta: float) -> int:
	var dir := held_direction()
	if dir == -1:
		_held_dir = -1
		return -1
	if dir != _held_dir:
		_held_dir = dir
		_timer = initial_delay
		return dir
	_timer -= delta
	if _timer <= 0.0:
		_timer += repeat_interval
		return dir
	return -1


## Camera pan input in [-1, 1] per axis (right stick or arrow keys).
func camera_vector() -> Vector2:
	return Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down", camera_deadzone)


static func _within_sector(v: Vector2, dir: int, half_width_deg: float) -> bool:
	var a := rad_to_deg(atan2(v.y, v.x))
	var diff := absf(wrapf(a - DIRECTION_ANGLES_DEG[dir], -180.0, 180.0))
	return diff <= half_width_deg


## "Xbox Controller (device 0)" or "No controller".
static func controller_status() -> String:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return "No controller"
	var names := []
	for p in pads:
		names.append("%s (device %d)" % [Input.get_joy_name(p), p])
	return ", ".join(names)
