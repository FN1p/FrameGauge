extends Node
## Run only in the validator's isolated project copy, with a graphical display.
var _failures := 0

func _check(ok: bool, description: String) -> void:
	if not ok:
		_failures += 1
		push_error("FAIL: " + description)

func _ready() -> void:
	await get_tree().process_frame
	var monitor := get_node_or_null("/root/PFTBenchmark")
	if not is_instance_valid(monitor) or not bool(monitor.call("is_monitor_available")):
		push_error("FrameGauge graphical smoke: runtime not available")
		get_tree().quit(1)
		return
	var panel := monitor.get("_panel") as Control
	var menu := monitor.get("_appearance") as Control
	var old_scale := float(monitor.get("_scale_factor"))
	var old_key := str(monitor.call("get_settings_shortcut"))
	monitor.call("set_overlay_visible", false)
	_check(not panel.visible and not monitor.is_processing(), "hidden HUD stops sampling")
	monitor.call("open_settings")
	await get_tree().process_frame
	_check(panel.visible and menu.visible, "settings open from hidden HUD")
	monitor.call("_quick_size", 0.5)
	monitor.call("_appearance_changed", 0.0, "background")
	monitor.call("_choose_runtime_layout", 2)
	monitor.call("_runtime_metric_changed", false, "fps")
	_check(int(monitor.get("_mode")) == 3 and not bool(monitor.call("_wanted", "fps")), "custom metric selection")
	monitor.call("_cancel_appearance")
	_check(not menu.visible and is_equal_approx(float(monitor.get("_scale_factor")), old_scale), "cancel restores appearance")
	monitor.call("open_settings")
	var event := InputEventKey.new()
	event.keycode = KEY_B
	event.ctrl_pressed = true
	event.shift_pressed = true
	event.pressed = true
	monitor.call("_capture_key", event)
	_check(str(monitor.call("get_settings_shortcut")) != old_key, "shortcut changed")
	var seed_cfg := ConfigFile.new()
	seed_cfg.set_value("future", "keep", 42)
	_check(seed_cfg.save("user://pft_benchmark_appearance.cfg") == OK, "seed future config")
	monitor.call("_quick_size", 0.75)
	_check(bool(monitor.call("_save_appearance")), "save settings")
	var cfg := ConfigFile.new()
	_check(cfg.load("user://pft_benchmark_appearance.cfg") == OK, "saved config readable")
	_check(is_equal_approx(float(cfg.get_value("hud", "scale", 0.0)), 0.75), "scale persisted")
	_check(int(cfg.get_value("controls", "menu_key", 0)) == KEY_B, "shortcut persisted")
	_check(int(cfg.get_value("future", "keep", 0)) == 42, "unknown config preserved")
	monitor.call("_close_appearance")
	monitor.call("_input", event)
	_check(menu.visible, "rebound shortcut opens menu")
	monitor.call("_cancel_appearance")
	monitor.call("set_input_locked", true)
	monitor.call("open_settings")
	_check(not menu.visible, "input lock respected")
	monitor.call("set_input_locked", false)
	monitor.call("open_settings")
	_check(menu.visible, "input lock released")
	monitor.call("_cancel_appearance")
	monitor.call("set_mode", 2)
	await get_tree().process_frame
	await get_tree().process_frame
	var bounds := get_viewport().get_visible_rect().size
	_check(panel.position.x >= 0.0 and panel.position.y >= 0.0 and panel.position.x + panel.size.x * panel.scale.x <= bounds.x + 2.0 and panel.position.y + panel.size.y * panel.scale.y <= bounds.y + 2.0, "HUD stays within viewport")
	print("Graphical smoke: %d failure(s)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
