@tool
extends RefCounted
## Modifier flags are deliberately independent of Godot's key mask values.
const CTRL := 1
const ALT := 2
const SHIFT := 4

static func modifiers(event: InputEventKey) -> int:
	return (CTRL if event.ctrl_pressed else 0) | (ALT if event.alt_pressed else 0) | (SHIFT if event.shift_pressed else 0)

static func supported_key(key: int) -> bool:
	return (key >= KEY_A and key <= KEY_Z) or (key >= KEY_0 and key <= KEY_9) or (key >= KEY_F1 and key <= KEY_F12)

static func valid(key: int, mods: int, toggle: int) -> bool:
	if not supported_key(key) or mods < 1 or mods > 7 or (mods & (CTRL | ALT)) == 0:
		return false
	if key == KEY_F4 and (mods & ALT) != 0:
		return false # OS window close shortcut.
	if key == toggle and (mods & ALT) == 0:
		return false # Existing toggle, reset and layout shortcuts.
	return true

static func text(key: int, mods: int) -> String:
	var parts := PackedStringArray()
	if (mods & CTRL) != 0:
		parts.append("Ctrl")
	if (mods & ALT) != 0:
		parts.append("Alt")
	if (mods & SHIFT) != 0:
		parts.append("Shift")
	parts.append(OS.get_keycode_string(key))
	return "+".join(parts)

static func matches(event: InputEventKey, key: int, mods: int) -> bool:
	return event.pressed and not event.echo and not event.meta_pressed and int(event.keycode) == key and modifiers(event) == mods
