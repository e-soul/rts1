extends RefCounted
## All input bindings in one place. Registered into the InputMap at startup so stick and
## button state is read through actions only. Gamepad bindings follow PROTOTYPE_PLAN.md;
## keyboard bindings are development fallbacks and sandbox commands.

const ALL_DEVICES := -1

## action -> list of bindings: ["key", Key], ["button", JoyButton], ["axis", JoyAxis, sign]
const BINDINGS := {
	# Design controls (gamepad first).
	"unit_prev": [["button", JOY_BUTTON_LEFT_SHOULDER], ["key", KEY_Q]],
	"unit_next": [["button", JOY_BUTTON_RIGHT_SHOULDER], ["key", KEY_R]],
	"default_action": [["button", JOY_BUTTON_A], ["key", KEY_ENTER], ["key", KEY_KP_ENTER]],
	"cancel": [["button", JOY_BUTTON_B], ["key", KEY_BACKSPACE]],
	"ability": [["button", JOY_BUTTON_X], ["key", KEY_F]],
	"pause": [["button", JOY_BUTTON_START], ["key", KEY_SPACE]],
	# Left stick: cursor. Read as a vector and snapped to six hex sectors.
	"cursor_left": [["axis", JOY_AXIS_LEFT_X, -1]],
	"cursor_right": [["axis", JOY_AXIS_LEFT_X, 1]],
	"cursor_up": [["axis", JOY_AXIS_LEFT_Y, -1]],
	"cursor_down": [["axis", JOY_AXIS_LEFT_Y, 1]],
	# Keyboard hex directions around S: W/E above, A/D sideways, Z/X below.
	"cursor_hex_e": [["key", KEY_D]],
	"cursor_hex_ne": [["key", KEY_E]],
	"cursor_hex_nw": [["key", KEY_W]],
	"cursor_hex_w": [["key", KEY_A]],
	"cursor_hex_sw": [["key", KEY_Z]],
	"cursor_hex_se": [["key", KEY_X]],
	# Right stick: camera.
	"camera_left": [["axis", JOY_AXIS_RIGHT_X, -1], ["key", KEY_LEFT]],
	"camera_right": [["axis", JOY_AXIS_RIGHT_X, 1], ["key", KEY_RIGHT]],
	"camera_up": [["axis", JOY_AXIS_RIGHT_Y, -1], ["key", KEY_UP]],
	"camera_down": [["axis", JOY_AXIS_RIGHT_Y, 1], ["key", KEY_DOWN]],
	# Sandbox commands (keyboard only, so the gamepad stays reserved for the design).
	"debug_overlay": [["key", KEY_F1]],
	"toggle_spawning": [["key", KEY_F2]],
	"spawn_enemy": [["key", KEY_F3]],
	"toggle_invulnerable": [["key", KEY_F4]],
	"reset_setup": [["key", KEY_F5]],
	"next_setup": [["key", KEY_F6]],
	"step_tick": [["key", KEY_PERIOD]],
	"slower": [["key", KEY_MINUS], ["key", KEY_KP_SUBTRACT]],
	"faster": [["key", KEY_EQUAL], ["key", KEY_PLUS], ["key", KEY_KP_ADD]],
	"toggle_help": [["key", KEY_H]],
}

## Keyboard hex-direction actions in Hex direction order (E, NE, NW, W, SW, SE).
const HEX_ACTIONS: Array[String] = [
	"cursor_hex_e", "cursor_hex_ne", "cursor_hex_nw", "cursor_hex_w", "cursor_hex_sw", "cursor_hex_se",
]


## Registers every action. Stick actions get a low InputMap deadzone; the real deadzones
## come from tuning and are applied to the combined stick vector.
static func register() -> void:
	for action in BINDINGS:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, 0.2)
		for b in BINDINGS[action]:
			InputMap.action_add_event(action, _event(b))


static func _event(b: Array) -> InputEvent:
	match b[0]:
		"key":
			var k := InputEventKey.new()
			k.physical_keycode = b[1]
			return k
		"button":
			var jb := InputEventJoypadButton.new()
			jb.device = ALL_DEVICES
			jb.button_index = b[1]
			return jb
		"axis":
			var jm := InputEventJoypadMotion.new()
			jm.device = ALL_DEVICES
			jm.axis = b[1]
			jm.axis_value = float(b[2])
			return jm
	return null
