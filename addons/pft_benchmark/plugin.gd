@tool
extends EditorPlugin

const FGMetrics = preload("res://addons/pft_benchmark/metric_config.gd")
const FGDock = preload("res://addons/pft_benchmark/settings_dock.gd")
const FGBridge = preload("res://addons/pft_benchmark/debug_bridge.gd")
var _dock: FGDock
var _bridge: FGBridge

const AUTOLOAD := "PFTBenchmark"
const RUNTIME := "res://addons/pft_benchmark/runtime.gd"
const PREFIX := "pft_benchmark/"
const SETTINGS := {
	"enabled": true,
	"show_on_start": true,
	"allow_release": false,
	"compact": false,
	"mode": 1,
	"accent_color": Color("81d6b4"),
	"language": 0,
	"graph_frames": 120,
	"show_graph": true,
	"graph_mode": 0,
	"show_system": true,
	"editor_telemetry": false,
	"show_memory": true,
	"show_render": true,
	"show_physics": true,
	"measure_render_time": false,
	"corner": 1,
	"scale": 0.8,
	"opacity": 0.85,
	"hud_opacity": 1.0,
	"refresh_hz": 4.0,
	"toggle_key": KEY_F9,
	"settings_key": KEY_F9,
	"settings_modifiers": 2,
	"sample_count": 600,
}

func _enter_tree() -> void:
	var changed := false
	var settings := SETTINGS.duplicate()
	settings["settings_key"] = int(ProjectSettings.get_setting(PREFIX + "toggle_key", KEY_F9))
	for id in FGMetrics.METRICS:
		settings["metric_" + id] = FGMetrics.default_enabled(id)
	for key in settings:
		var path := PREFIX + str(key)
		var default_value: Variant = settings[key]
		if not ProjectSettings.has_setting(path):
			ProjectSettings.set_setting(path, default_value)
			changed = true
		ProjectSettings.set_initial_value(path, default_value)
		ProjectSettings.add_property_info({"name": path, "type": typeof(default_value)})
	ProjectSettings.add_property_info({"name": PREFIX + "corner", "type": TYPE_INT, "hint": PROPERTY_HINT_ENUM, "hint_string": "Top left,Top right,Bottom left,Bottom right"})
	ProjectSettings.add_property_info({"name": PREFIX + "scale", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.4,2.0,0.05"})
	ProjectSettings.add_property_info({"name": PREFIX + "opacity", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01"})
	ProjectSettings.add_property_info({"name": PREFIX + "hud_opacity", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.35,1.0,0.01"})
	ProjectSettings.add_property_info({"name": PREFIX + "refresh_hz", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "1.0,10.0,0.5"})
	ProjectSettings.add_property_info({"name": PREFIX + "sample_count", "type": TYPE_INT, "hint": PROPERTY_HINT_RANGE, "hint_string": "120,1200,60"})
	ProjectSettings.add_property_info({"name": PREFIX + "mode", "type": TYPE_INT, "hint": PROPERTY_HINT_ENUM, "hint_string": "Minimal,Standard,Full,Custom"})
	ProjectSettings.add_property_info({"name": PREFIX + "language", "type": TYPE_INT, "hint": PROPERTY_HINT_ENUM, "hint_string": "English,Русский"})
	ProjectSettings.add_property_info({"name": PREFIX + "graph_frames", "type": TYPE_INT, "hint": PROPERTY_HINT_RANGE, "hint_string": "30,600,30"})
	ProjectSettings.add_property_info({"name": PREFIX + "graph_mode", "type": TYPE_INT, "hint": PROPERTY_HINT_ENUM, "hint_string": "Frame time,Instantaneous FPS"})
	if changed:
		ProjectSettings.save()
	_dock = FGDock.new()
	_dock.build(settings)
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _dock)
	_bridge = FGBridge.new()
	_bridge.sample_received.connect(_dock.receive_sample)
	add_debugger_plugin(_bridge)

func _exit_tree() -> void:
	if is_instance_valid(_bridge):
		remove_debugger_plugin(_bridge)
		_bridge = null
	if is_instance_valid(_dock):
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null

func _enable_plugin() -> void:
	var path := "autoload/" + AUTOLOAD
	if not ProjectSettings.has_setting(path):
		add_autoload_singleton(AUTOLOAD, RUNTIME)
	elif not _owns_autoload():
		push_warning("FrameGauge: autoload name already in use. Rename the conflicting autoload before enabling the plugin.")

func _disable_plugin() -> void:
	if _owns_autoload():
		remove_autoload_singleton(AUTOLOAD)

func _owns_autoload() -> bool:
	var path := str(ProjectSettings.get_setting("autoload/" + AUTOLOAD, ""))
	return path == RUNTIME or path == "*" + RUNTIME
