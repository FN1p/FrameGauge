extends SceneTree
const FGShortcut = preload("res://addons/pft_benchmark/shortcut_config.gd")
func _initialize() -> void:
	var checks := [
		FGShortcut.valid(KEY_F9, FGShortcut.ALT, KEY_F9),
		FGShortcut.valid(KEY_B, FGShortcut.CTRL | FGShortcut.SHIFT, KEY_F9),
		not FGShortcut.valid(KEY_F9, FGShortcut.CTRL, KEY_F9),
		not FGShortcut.valid(KEY_F9, FGShortcut.CTRL | FGShortcut.SHIFT, KEY_F9),
		not FGShortcut.valid(KEY_F4, FGShortcut.ALT, KEY_F9),
		not FGShortcut.valid(KEY_B, 0, KEY_F9),
		not FGShortcut.valid(KEY_ESCAPE, FGShortcut.CTRL, KEY_F9),
	]
	var event := InputEventKey.new()
	event.keycode = KEY_B
	event.ctrl_pressed = true
	event.shift_pressed = true
	event.pressed = true
	checks.append(FGShortcut.matches(event, KEY_B, FGShortcut.CTRL | FGShortcut.SHIFT))
	checks.append(not FGShortcut.matches(event, KEY_B, FGShortcut.CTRL))
	event.echo = true
	checks.append(not FGShortcut.matches(event, KEY_B, FGShortcut.CTRL | FGShortcut.SHIFT))
	if checks.has(false):
		push_error("Shortcut validation failed")
		quit(1)
		return
	print("Shortcut checks passed")
	quit(0)
