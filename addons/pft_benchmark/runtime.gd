extends CanvasLayer
## Debug-only by default. No external processes or native dependencies.

const FGMetrics = preload("res://addons/pft_benchmark/metric_config.gd")
const FGStats = preload("res://addons/pft_benchmark/frame_stats.gd")
const FGHost = preload("res://addons/pft_benchmark/system_metrics.gd")
const FGGraph = preload("res://addons/pft_benchmark/frame_graph.gd")
const FGStyle = preload("res://addons/pft_benchmark/ui_style.gd")
const FGShortcut = preload("res://addons/pft_benchmark/shortcut_config.gd")
const PREFIX := "pft_benchmark/"
const INK := Color("e7edf6")
const MUTED := Color("a2aebf")
const ACCENT := Color("81d6b4")
var _metric_nodes := {}
var _summary_separator: HSeparator
var _stats_separator: HSeparator
var _timing_separator: HSeparator
var _advanced_separator: HSeparator
var _selected := {}
var _hardware: Label
var _top: HBoxContainer
var _summary: HBoxContainer
var _stats: FGStats
var _host := FGHost.new()
var _host_at := -1000
var _host_ram: Label
var _host_cpu: Label
var _host_gpu: Label
var _show_system := true
var _telemetry := false
var _telemetry_at := -1000
var _layout_queued := false
var _panel: PanelContainer
var _details: VBoxContainer
var _graph: FGGraph
var _fps: Label
var _average: Label
var _low: Label
var _frame: Label
var _memory: Label
var _vram: Label
var _calls: Label
var _primitives: Label
var _nodes: Label
var _objects: Label
var _footer: Label
var _input_locked := false
var _mode := 1
var _advanced: VBoxContainer
var _timing: VBoxContainer
var _process_time: Label
var _physics_time: Label
var _cpu_render: Label
var _gpu_render: Label
var _range: Label
var _spikes: Label
var _active: Label
var _pairs: Label
var _self_cost: Label
var _custom_position := false
var _dragging := false
var _drag_offset := Vector2.ZERO
var _viewport_rid := RID()
var _measure_render := false
var _owns_measurement := false
var _update_cost := 0.0
var _graph_count := 120
var _show_graph := true
var _show_memory := true
var _show_render := true
var _show_physics := true
var _lang := 0
var _compact := false
var _corner := 1
var _scale_factor := 0.8
var _bg_opacity := 0.85
var _hud_opacity := 1.0
var _hud_style: StyleBoxFlat
var _appearance: PanelContainer
var _appearance_sliders := {}
var _appearance_readouts := {}
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _appearance_status: Label
var _appearance_mode: OptionButton
var _appearance_corner: OptionButton
var _appearance_metrics := {}
var _settings_button: Button
const LOCAL_STYLE := "user://pft_benchmark_appearance.cfg"
var _refresh := 0.25
var _key: int = KEY_F9
var _menu_key: int = KEY_F9
var _menu_mods := FGShortcut.ALT
var _capture_shortcut := false
var _shortcut_button: Button
var _shortcut_hint: Label
var _advanced_fields := {}
var _snapshot := {}
var _graph_mode := 0
var _sample_count := 600
var _menu_blocker: ColorRect
var _settings_tabs: TabContainer
var _last_us := 0
var _elapsed := 0.0
var _available := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	set_process_input(false)
	if not bool(_setting("enabled", true)):
		return
	if not OS.is_debug_build() and not bool(_setting("allow_release", false)):
		return
	if DisplayServer.get_name() == "headless":
		return
	_available = true
	layer = 100
	_mode = clampi(int(_setting("mode", 1)), 0, 3)
	if bool(_setting("compact", false)):
		_mode = 0
	_compact = _mode == 0
	_graph_count = clampi(int(_setting("graph_frames", 120)), 30, 600)
	_show_graph = bool(_setting("show_graph", true))
	_show_system = bool(_setting("show_system", true))
	_telemetry = OS.is_debug_build() and bool(_setting("editor_telemetry", false))
	_show_memory = bool(_setting("show_memory", true))
	_show_render = bool(_setting("show_render", true))
	_show_physics = bool(_setting("show_physics", true))
	_lang = int(_setting("language", 0))
	_measure_render = bool(_setting("measure_render_time", false))
	_viewport_rid = get_viewport().get_viewport_rid()
	_corner = clampi(int(_setting("corner", 1)), 0, 3)
	_scale_factor = clampf(float(_setting("scale", 0.8)), 0.4, 2.0)
	_bg_opacity = clampf(float(_setting("opacity", 0.85)), 0.0, 1.0)
	_hud_opacity = clampf(float(_setting("hud_opacity", 1.0)), 0.35, 1.0)
	_load_local_appearance()
	_refresh = 1.0 / clampf(float(_setting("refresh_hz", 4.0)), 1.0, 10.0)
	_key = int(_setting("toggle_key", KEY_F9))
	_load_project_controls()
	_load_local_controls()
	_stats = FGStats.new(_sample_count)
	for id in FGMetrics.METRICS:
		_selected[id] = FGMetrics.selected(id)
	_load_local_layout()
	_build_ui()
	_apply_visibility()
	get_viewport().size_changed.connect(_place_panel)
	_panel.minimum_size_changed.connect(_schedule_place)
	set_process_input(true)
	set_overlay_visible(bool(_setting("show_on_start", true)))

func _setting(name: String, fallback: Variant) -> Variant:
	return ProjectSettings.get_setting(PREFIX + name, fallback)

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "BenchmarkHUD"
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_style = FGStyle.panel(FGStyle.SURFACE, FGStyle.LINE, 6, 8.0)
	_panel.add_theme_stylebox_override("panel", _hud_style)
	_apply_appearance()
	add_child(_panel)
	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 3)
	body.custom_minimum_size.x = 210.0
	_panel.add_child(body)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(head)
	var brand := _label("FrameGauge", 12, _accent())
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(brand)
	_settings_button = Button.new()
	_settings_button.text = _local("Settings")
	_settings_button.tooltip_text = _local("HUD settings") + " (" + get_settings_shortcut() + ")"
	_settings_button.add_theme_font_size_override("font_size", 11)
	FGStyle.button(_settings_button)
	_settings_button.custom_minimum_size.y = 20
	_settings_button.focus_mode = Control.FOCUS_NONE
	_settings_button.pressed.connect(open_settings)
	head.add_child(_settings_button)
	var top := HBoxContainer.new()
	_top = top
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 8)
	body.add_child(top)
	_fps = _metric(top, "FPS", "--", 24, _accent())
	_frame = _metric(top, "FRAME TIME", "-- ms", 18, INK)
	_details = VBoxContainer.new()
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.add_theme_constant_override("separation", 3)
	body.add_child(_details)
	_summary_separator = _divider(_details)
	var summary := HBoxContainer.new()
	_summary = summary
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.add_theme_constant_override("separation", 8)
	_details.add_child(summary)
	_average = _metric(summary, "AVG FPS", "--", 17, INK)
	_low = _metric(summary, "1% LOW", "--", 17, INK)
	_graph = FGGraph.new()
	_graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph.custom_minimum_size = Vector2(0, 58)
	_details.add_child(_graph)
	_graph.visible = _show_graph
	_graph.line_color = _accent()
	_graph.fps_mode = _graph_mode == 1
	_graph.russian = _lang == 1
	_stats_separator = _divider(_details)
	_memory = _stat(_details, "Engine memory")
	_vram = _stat(_details, "Video memory")
	_host_ram = _stat(_details, "Host free / total RAM")
	_host_cpu = _stat(_details, "Host CPU busy")
	_host_gpu = _stat(_details, "DRM GPU busy")
	for value in [_host_ram, _host_cpu, _host_gpu]:
		value.get_parent().visible = _show_system
	_calls = _stat(_details, "Render draw calls")
	_primitives = _stat(_details, "Render primitives")
	_nodes = _stat(_details, "Nodes")
	_objects = _stat(_details, "Render objects")
	for value in [_memory, _vram]:
		value.get_parent().visible = _show_memory
	for value in [_calls, _primitives, _nodes, _objects]:
		value.get_parent().visible = _show_render
	_timing_separator = _divider(_details)
	_timing = VBoxContainer.new()
	_timing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.add_child(_timing)
	_process_time = _stat(_timing, "Process time")
	_physics_time = _stat(_timing, "Physics time")
	_physics_time.get_parent().visible = _show_physics
	_cpu_render = _stat(_timing, "Render CPU")
	_gpu_render = _stat(_timing, "Render GPU")
	_advanced_separator = _divider(_details)
	_advanced = VBoxContainer.new()
	_advanced.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_advanced.add_theme_constant_override("separation", 3)
	_details.add_child(_advanced)
	_range = _stat(_advanced, "Min / Max FPS")
	_spikes = _stat(_advanced, "Frames > 33ms")
	_active = _stat(_advanced, "Active bodies 2D/3D")
	_pairs = _stat(_advanced, "Pairs 2D/3D")
	_active.get_parent().visible = _show_physics
	_pairs.get_parent().visible = _show_physics
	_self_cost = _stat(_advanced, "HUD update CPU")
	var hardware := _label(OS.get_processor_name() + "\n" + RenderingServer.get_video_adapter_name() + "\nGodot " + str(Engine.get_version_info().get("string", "")) + " / " + str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")), 10, MUTED)
	hardware.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hardware.custom_minimum_size.x = 202
	_advanced.add_child(hardware)
	_hardware = hardware
	_footer = _label("", 10, MUTED)
	body.add_child(_footer)
	_metric_nodes = {
		"fps": _fps.get_parent(),
		"frame": _frame.get_parent(),
		"average": _average.get_parent(),
		"low": _low.get_parent(),
		"graph": _graph,
		"memory": _memory.get_parent(),
		"vram": _vram.get_parent(),
		"host_ram": _host_ram.get_parent(),
		"host_cpu": _host_cpu.get_parent(),
		"host_gpu": _host_gpu.get_parent(),
		"calls": _calls.get_parent(),
		"primitives": _primitives.get_parent(),
		"nodes": _nodes.get_parent(),
		"objects": _objects.get_parent(),
		"process_time": _process_time.get_parent(),
		"physics_time": _physics_time.get_parent(),
		"cpu_render": _cpu_render.get_parent(),
		"gpu_render": _gpu_render.get_parent(),
		"range": _range.get_parent(),
		"spikes": _spikes.get_parent(),
		"active": _active.get_parent(),
		"pairs": _pairs.get_parent(),
		"self_cost": _self_cost.get_parent(),
		"hardware": _hardware,
	}
	_update_footer()
	_build_appearance_panel()

func _wanted(id: String) -> bool:
	return bool(_selected.get(id, true)) and FGMetrics.visible_in_mode(id, _mode)

func _apply_visibility() -> void:
	for id in _metric_nodes:
		(_metric_nodes[id] as Control).visible = _wanted(id)
	_top.visible = _wanted("fps") or _wanted("frame")
	_summary.visible = _wanted("average") or _wanted("low")
	_timing.visible = _wanted("process_time") or _wanted("physics_time") or _wanted("cpu_render") or _wanted("gpu_render")
	_advanced.visible = _wanted("range") or _wanted("spikes") or _wanted("active") or _wanted("pairs") or _wanted("self_cost") or _wanted("hardware")
	_details.visible = _summary.visible or _timing.visible or _advanced.visible or _wanted("graph") or _wanted("memory") or _wanted("vram") or _wanted("host_ram") or _wanted("host_cpu") or _wanted("host_gpu") or _wanted("calls") or _wanted("primitives") or _wanted("nodes") or _wanted("objects")
	_summary_separator.visible = _top.visible and _summary.visible
	var basic := _wanted("memory") or _wanted("vram") or _wanted("host_ram") or _wanted("host_cpu") or _wanted("host_gpu") or _wanted("calls") or _wanted("nodes") or _wanted("primitives") or _wanted("objects")
	_stats_separator.visible = basic and (_top.visible or _summary.visible or _wanted("graph"))
	_timing_separator.visible = _timing.visible and (basic or _top.visible or _summary.visible or _wanted("graph"))
	_advanced_separator.visible = _advanced.visible and (_timing.visible or basic or _top.visible or _summary.visible or _wanted("graph"))
	_update_measurement()

func _divider(parent: VBoxContainer) -> HSeparator:
	var separator := HSeparator.new()
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rule := StyleBoxLine.new()
	rule.color = Color(0.40, 0.46, 0.52, 0.30)
	rule.thickness = 1
	separator.add_theme_stylebox_override("separator", rule)
	separator.add_theme_constant_override("separation", 5)
	parent.add_child(separator)
	return separator

func _update_measurement() -> void:
	if not _viewport_rid.is_valid():
		return
	var needed := _measure_render and _panel.visible and (_wanted("cpu_render") or _wanted("gpu_render") or _telemetry)
	if needed != _owns_measurement:
		RenderingServer.viewport_set_measure_render_time(_viewport_rid, needed)
		_owns_measurement = needed

func _label(value: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = _local(value)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result

func _metric(parent: HBoxContainer, caption: String, initial: String, font_size: int, color: Color) -> Label:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 1)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	box.add_child(_label(caption, 10, MUTED))
	var value := _label(initial, font_size, color)
	box.add_child(value)
	return value

func _stat(parent: VBoxContainer, caption: String) -> Label:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var label := _label(caption, 11, MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value := _label("--", 11, INK)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return value

func _update_footer() -> void:
	_footer.text = "%s: %s  ·  %s: %s" % [OS.get_keycode_string(_key), _local("Hide"), get_settings_shortcut(), _local("Settings")]
	if is_instance_valid(_settings_button):
		_settings_button.tooltip_text = _local("HUD settings") + " (" + get_settings_shortcut() + ")"

func get_settings_shortcut() -> String:
	return FGShortcut.text(_menu_key, _menu_mods)

func _schedule_place() -> void:
	if not _layout_queued:
		_layout_queued = true
		_place_panel.call_deferred()

func _place_panel() -> void:
	_layout_queued = false
	if not is_instance_valid(_panel):
		return
	_panel.reset_size()
	var viewport_size := get_viewport().get_visible_rect().size
	var base_size := _panel.get_combined_minimum_size()
	# Fit small windows without changing the user's configured scale.
	var fitted := minf(_scale_factor, minf(maxf(1.0, viewport_size.x - 24.0) / maxf(1.0, base_size.x), maxf(1.0, viewport_size.y - 24.0) / maxf(1.0, base_size.y)))
	_panel.scale = Vector2.ONE * fitted
	var bounds := base_size * fitted
	var x := 12.0 if _corner == 0 or _corner == 2 else maxf(12.0, viewport_size.x - bounds.x - 12.0)
	var y := 12.0 if _corner < 2 else maxf(12.0, viewport_size.y - bounds.y - 12.0)
	if _custom_position:
		_panel.position = Vector2(clampf(_panel.position.x, 0.0, maxf(0.0, viewport_size.x - bounds.x)), clampf(_panel.position.y, 0.0, maxf(0.0, viewport_size.y - bounds.y)))
	else:
		_panel.position = Vector2(x, y)
	_position_appearance()

func set_overlay_visible(enabled: bool) -> void:
	if not _available:
		return
	if _panel.visible == enabled and is_processing() == enabled:
		return
	_panel.visible = enabled
	if not enabled:
		_cancel_appearance()
	_dragging = false
	_update_measurement()
	set_process(enabled)
	_stats.clear()
	_last_us = 0
	_elapsed = 0.0
	_host_at = -1000
	_host = FGHost.new()
	if enabled:
		_update_values()
		_place_panel.call_deferred()

func set_compact(enabled: bool) -> void:
	set_mode(0 if enabled else 1)

## Public entry point for a game's debug menu or the demo lab.
func open_settings() -> void:
	if not _available or _input_locked:
		return
	if not _panel.visible:
		set_overlay_visible(true)
	if not _appearance.visible:
		_open_appearance()

func set_mode(mode: int) -> void:
	if not _available:
		return
	_mode = clampi(mode, 0, 3)
	_compact = _mode == 0
	_apply_visibility()
	_update_values()
	_place_panel.call_deferred()

func reset_stats() -> void:
	if not _available:
		return
	_stats.clear()
	_last_us = 0
	_elapsed = 0.0
	_update_values()

func is_monitor_available() -> bool:
	return _available

func is_overlay_visible() -> bool:
	return _available and _panel.visible

func _exit_tree() -> void:
	_close_appearance()
	if _owns_measurement and _viewport_rid.is_valid():
		RenderingServer.viewport_set_measure_render_time(_viewport_rid, false)

func set_input_locked(locked: bool) -> void:
	_input_locked = locked
	if is_instance_valid(_settings_button):
		_settings_button.disabled = locked
	if locked:
		_cancel_appearance()
	_dragging = false

func _input(event: InputEvent) -> void:
	if _input_locked:
		return
	if _capture_shortcut and event is InputEventKey:
		get_viewport().set_input_as_handled()
		if event.pressed and not event.echo:
			_capture_key(event)
		return
	if event is InputEventKey and FGShortcut.matches(event, _menu_key, _menu_mods):
		if _appearance.visible:
			_cancel_appearance()
		else:
			open_settings()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(_appearance) and _appearance.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_cancel_appearance()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.alt_pressed and _panel.visible and Rect2(_panel.position, _panel.size * _panel.scale).has_point(event.position):
			_dragging = true
			_custom_position = true
			_drag_offset = event.position - _panel.position
			get_viewport().set_input_as_handled()
		elif not event.pressed and _dragging:
			_dragging = false
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		_panel.position = event.position - _drag_offset
		_place_panel()
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and int(event.keycode) == _key:
		if event.alt_pressed or event.meta_pressed:
			return
		if event.ctrl_pressed and event.shift_pressed:
			_custom_position = false
			_place_panel()
		elif event.ctrl_pressed:
			reset_stats()
		elif event.shift_pressed:
			if _panel.visible:
				set_mode((_mode + 1) % 4)
		else:
			set_overlay_visible(not _panel.visible)
		get_viewport().set_input_as_handled()

func _load_local_appearance() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(LOCAL_STYLE) != OK:
		return
	var scale_value: Variant = cfg.get_value("hud", "scale", _scale_factor)
	var bg_value: Variant = cfg.get_value("hud", "background", _bg_opacity)
	var opacity_value: Variant = cfg.get_value("hud", "opacity", _hud_opacity)
	if (scale_value is float or scale_value is int) and is_finite(float(scale_value)):
		_scale_factor = clampf(float(scale_value), 0.4, 2.0)
	if (bg_value is float or bg_value is int) and is_finite(float(bg_value)):
		_bg_opacity = clampf(float(bg_value), 0.0, 1.0)
	if (opacity_value is float or opacity_value is int) and is_finite(float(opacity_value)):
		_hud_opacity = clampf(float(opacity_value), 0.35, 1.0)

func _load_local_layout() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(LOCAL_STYLE) != OK:
		return
	var mode: Variant = cfg.get_value("hud", "mode", _mode)
	var corner: Variant = cfg.get_value("hud", "corner", _corner)
	if mode is int:
		_mode = clampi(mode, 0, 3)
		_compact = _mode == 0
	if corner is int:
		_corner = clampi(corner, 0, 3)
	var selected: Variant = cfg.get_value("hud", "metrics", {})
	if selected is Dictionary:
		for id in FGMetrics.METRICS:
			if selected.has(id) and selected[id] is bool:
				_selected[id] = selected[id]

func _apply_appearance() -> void:
	if not is_instance_valid(_panel):
		return
	var bg: Color = FGStyle.SURFACE
	bg.a = _bg_opacity
	var border: Color = FGStyle.LINE
	border.a = _bg_opacity
	_hud_style.bg_color = bg
	_hud_style.border_color = border
	_panel.modulate.a = _hud_opacity
	_schedule_place()

func _build_appearance_panel() -> void:
	# Transparent input shield keeps clicks from reaching the game's Controls.
	_menu_blocker = ColorRect.new()
	_menu_blocker.color = Color.TRANSPARENT
	_menu_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_blocker.hide()
	add_child(_menu_blocker)
	_appearance = PanelContainer.new()
	_appearance.name = "BenchmarkAppearance"
	_appearance.add_theme_stylebox_override("panel", FGStyle.panel(Color("171e27"), FGStyle.LINE, 8, 12.0))
	_appearance.hide()
	add_child(_appearance)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 424.0
	box.add_theme_constant_override("separation", 7)
	_appearance.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var heading := Label.new()
	heading.text = "FrameGauge  /  " + _local("Settings")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_color_override("font_color", _accent())
	heading.add_theme_font_size_override("font_size", 16)
	header.add_child(heading)
	var close := Button.new()
	close.text = "×"
	close.tooltip_text = _local("Close") + " (Esc)"
	FGStyle.button(close)
	close.pressed.connect(_cancel_appearance)
	header.add_child(close)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size.y = 360
	_settings_tabs = tabs
	box.add_child(tabs)
	var style_scroll := ScrollContainer.new()
	style_scroll.name = _local("Appearance")
	style_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(style_scroll)
	var style := VBoxContainer.new()
	style.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style.add_theme_constant_override("separation", 5)
	style_scroll.add_child(style)
	_appearance_mode = _appearance_choice(style, "Layout", ["Minimal", "Standard", "Full", "Custom"])
	_appearance_mode.item_selected.connect(_choose_runtime_layout)
	_appearance_corner = _appearance_choice(style, "Position", ["Top left", "Top right", "Bottom left", "Bottom right"])
	_appearance_corner.item_selected.connect(func(index: int):
		_corner = index
		_custom_position = false
		_schedule_place()
	)
	_appearance_slider(style, "scale", "HUD size", 0.4, 2.0)
	var quick := HBoxContainer.new()
	style.add_child(quick)
	for factor in [0.5, 0.75, 1.0]:
		var b := Button.new()
		b.text = "%d%%" % roundi(factor * 100.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		FGStyle.button(b)
		b.pressed.connect(_quick_size.bind(factor))
		quick.add_child(b)
	_appearance_slider(style, "background", "Background opacity", 0.0, 1.0)
	_appearance_slider(style, "opacity", "Overall HUD opacity", 0.35, 1.0)
	var metrics_scroll := ScrollContainer.new()
	metrics_scroll.name = _local("Metrics")
	metrics_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(metrics_scroll)
	var metric_box := VBoxContainer.new()
	metric_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metrics_scroll.add_child(metric_box)
	var hint := Label.new()
	hint.text = _local("Choose what the HUD shows. Changes select Custom.")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	metric_box.add_child(hint)
	for group in FGMetrics.GROUPS:
		var section := Label.new()
		section.text = _local(str(group).capitalize())
		section.add_theme_color_override("font_color", _accent())
		metric_box.add_child(section)
		for id in FGMetrics.GROUPS[group]:
			var check := CheckBox.new()
			check.text = _local(str(FGMetrics.METRICS[id][0]))
			check.toggled.connect(_runtime_metric_changed.bind(id))
			metric_box.add_child(check)
			_appearance_metrics[id] = check
	_build_controls_tab(tabs)
	_build_advanced_tab(tabs)
	tabs.tab_changed.connect(func(_tab_index: int):
		_capture_shortcut = false
		_sync_extra_controls()
	)
	var row := HBoxContainer.new()
	box.add_child(row)
	var reset := Button.new()
	reset.text = _local("Project defaults")
	FGStyle.button(reset)
	reset.pressed.connect(_reset_appearance)
	row.add_child(reset)
	var cancel := Button.new()
	cancel.text = _local("Cancel")
	FGStyle.button(cancel)
	cancel.pressed.connect(_cancel_appearance)
	row.add_child(cancel)
	var apply := Button.new()
	apply.text = _local("Apply")
	FGStyle.button(apply)
	apply.pressed.connect(func():
		_capture_shortcut = false
		_sync_extra_controls()
		if _save_appearance():
			_snapshot = _capture_settings()
	)
	row.add_child(apply)
	var save := Button.new()
	save.text = _local("Save & close")
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	FGStyle.button(save, true)
	save.pressed.connect(func():
		if _save_appearance():
			_snapshot.clear()
			_close_appearance()
	)
	row.add_child(save)
	_appearance_status = Label.new()
	_appearance_status.text = _local("Changes preview instantly")
	_appearance_status.add_theme_font_size_override("font_size", 11)
	_appearance_status.add_theme_color_override("font_color", MUTED)
	_appearance_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_appearance_status)
	_sync_appearance()

func _appearance_choice(parent: VBoxContainer, caption: String, values: Array) -> OptionButton:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = _local(caption)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var choice := OptionButton.new()
	for value in values:
		choice.add_item(_local(str(value)))
	row.add_child(choice)
	return choice

func _quick_size(factor: float) -> void:
	(_appearance_sliders["scale"] as HSlider).value = factor

func _choose_runtime_layout(mode: int) -> void:
	# Explicit presets restore all metrics, filtered by the selected layout.
	if mode != 3:
		for id in FGMetrics.METRICS:
			_selected[id] = true
	set_mode(mode)
	_sync_appearance()

func _runtime_metric_changed(enabled: bool, id: String) -> void:
	# Start Custom from exactly the currently visible metrics.
	if _mode != 3:
		for metric in FGMetrics.METRICS:
			_selected[metric] = _wanted(metric)
	_selected[id] = enabled
	_host_at = -1000
	set_mode(3)
	_sync_appearance()

func _appearance_slider(parent: VBoxContainer, key: String, caption: String, low: float, high: float) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var title := Label.new()
	title.text = _local(caption)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var readout := Label.new()
	readout.add_theme_color_override("font_color", _accent())
	row.add_child(readout)
	var slider_node := HSlider.new()
	slider_node.min_value = low
	slider_node.max_value = high
	slider_node.step = 0.05
	FGStyle.slider(slider_node)
	parent.add_child(slider_node)
	_appearance_sliders[key] = slider_node
	_appearance_readouts[key] = readout
	slider_node.value_changed.connect(_appearance_changed.bind(key))

func _appearance_changed(value: float, key: String) -> void:
	match key:
		"scale": _scale_factor = value
		"background": _bg_opacity = value
		"opacity": _hud_opacity = value
	(_appearance_readouts[key] as Label).text = "%d%%" % roundi(value * 100.0)
	_appearance_status.text = _local("Changes preview instantly")
	_apply_appearance()

func _sync_appearance() -> void:
	if not is_instance_valid(_appearance_mode):
		return
	_appearance_mode.select(_mode)
	_appearance_corner.select(_corner)
	for id in _appearance_metrics:
		(_appearance_metrics[id] as CheckBox).set_pressed_no_signal(_wanted(id))
	var values := {"scale": _scale_factor, "background": _bg_opacity, "opacity": _hud_opacity}
	for key in values:
		(_appearance_sliders[key] as HSlider).set_value_no_signal(float(values[key]))
		(_appearance_readouts[key] as Label).text = "%d%%" % roundi(float(values[key]) * 100.0)
	_sync_extra_controls()

func _save_appearance() -> bool:
	var cfg := ConfigFile.new()
	# Preserve unknown keys so future versions can share the same config.
	if FileAccess.file_exists(LOCAL_STYLE) and cfg.load(LOCAL_STYLE) != OK:
		cfg.clear()
	cfg.set_value("hud", "scale", _scale_factor)
	cfg.set_value("hud", "background", _bg_opacity)
	cfg.set_value("hud", "opacity", _hud_opacity)
	cfg.set_value("hud", "mode", _mode)
	cfg.set_value("hud", "corner", _corner)
	cfg.set_value("hud", "metrics", _selected.duplicate())
	cfg.set_value("controls", "menu_key", _menu_key)
	cfg.set_value("controls", "menu_mods", _menu_mods)
	cfg.set_value("advanced", "refresh_hz", 1.0 / _refresh)
	cfg.set_value("advanced", "sample_count", _sample_count)
	cfg.set_value("advanced", "graph_frames", _graph_count)
	cfg.set_value("advanced", "graph_mode", _graph_mode)
	cfg.set_value("advanced", "measure_render_time", _measure_render)
	var error := cfg.save(LOCAL_STYLE)
	_appearance_status.text = _local("Saved locally") if error == OK else "Save failed: %d" % error
	return error == OK

func _reset_appearance() -> void:
	_corner = clampi(int(_setting("corner", 1)), 0, 3)
	_custom_position = false
	for id in FGMetrics.METRICS:
		_selected[id] = FGMetrics.selected(id)
	set_mode(0 if bool(_setting("compact", false)) else int(_setting("mode", 1)))
	_scale_factor = clampf(float(_setting("scale", 0.8)), 0.4, 2.0)
	_bg_opacity = clampf(float(_setting("opacity", 0.85)), 0.0, 1.0)
	_hud_opacity = clampf(float(_setting("hud_opacity", 1.0)), 0.35, 1.0)
	_capture_shortcut = false
	_load_project_controls()
	_apply_advanced()
	_update_footer()
	_sync_appearance()
	_apply_appearance()
	_appearance_status.text = _local("Defaults previewed. Save to keep them.")

func _open_appearance() -> void:
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_dragging = false
	_snapshot = _capture_settings()
	_capture_shortcut = false
	_sync_appearance()
	_appearance_status.text = _local("Changes preview instantly")
	_menu_blocker.show()
	_appearance.show()
	_position_appearance()

func _close_appearance() -> void:
	if not is_instance_valid(_appearance) or not _appearance.visible:
		return
	_capture_shortcut = false
	_snapshot.clear()
	_appearance.hide()
	_menu_blocker.hide()
	Input.mouse_mode = _previous_mouse_mode

func _position_appearance() -> void:
	if not is_instance_valid(_appearance) or not _appearance.visible:
		return
	_appearance.reset_size()
	var bounds := get_viewport().get_visible_rect().size
	_menu_blocker.size = bounds
	var sz := _appearance.get_combined_minimum_size()
	var fit := minf(1.0, minf(maxf(1.0, bounds.x - 16.0) / maxf(1.0, sz.x), maxf(1.0, bounds.y - 16.0) / maxf(1.0, sz.y)))
	_appearance.scale = Vector2.ONE * fit
	_appearance.position = (bounds - sz * fit) * 0.5

func _load_project_controls() -> void:
	_menu_key = int(_setting("settings_key", _key))
	_menu_mods = int(_setting("settings_modifiers", FGShortcut.ALT))
	if not FGShortcut.valid(_menu_key, _menu_mods, _key):
		_menu_key = KEY_F9
		_menu_mods = FGShortcut.ALT
	_refresh = 1.0 / clampf(float(_setting("refresh_hz", 4.0)), 1.0, 10.0)
	_sample_count = clampi(int(_setting("sample_count", 600)), 120, 1200)
	_graph_count = clampi(int(_setting("graph_frames", 120)), 30, 600)
	_graph_mode = clampi(int(_setting("graph_mode", 0)), 0, 1)
	_measure_render = bool(_setting("measure_render_time", false))

func _load_local_controls() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(LOCAL_STYLE) != OK:
		return
	var key: Variant = cfg.get_value("controls", "menu_key", _menu_key)
	var mods: Variant = cfg.get_value("controls", "menu_mods", _menu_mods)
	if key is int and mods is int and FGShortcut.valid(key, mods, _key):
		_menu_key = key
		_menu_mods = mods
	var hz: Variant = cfg.get_value("advanced", "refresh_hz", 1.0 / _refresh)
	if (hz is float or hz is int) and is_finite(float(hz)):
		_refresh = 1.0 / clampf(float(hz), 1.0, 10.0)
	var samples: Variant = cfg.get_value("advanced", "sample_count", _sample_count)
	var frames: Variant = cfg.get_value("advanced", "graph_frames", _graph_count)
	var graph_mode: Variant = cfg.get_value("advanced", "graph_mode", _graph_mode)
	var timing: Variant = cfg.get_value("advanced", "measure_render_time", _measure_render)
	if samples is int:
		_sample_count = clampi(samples, 120, 1200)
	if frames is int:
		_graph_count = clampi(frames, 30, 600)
	if graph_mode is int:
		_graph_mode = clampi(graph_mode, 0, 1)
	if timing is bool:
		_measure_render = timing

func _settings_tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = _local(title)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 7)
	scroll.add_child(box)
	return box

func _note(parent: VBoxContainer, text: String) -> Label:
	var label := Label.new()
	label.text = _local(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", MUTED)
	label.add_theme_font_size_override("font_size", 12)
	parent.add_child(label)
	return label

func _build_controls_tab(tabs: TabContainer) -> void:
	var box := _settings_tab(tabs, "Controls")
	_note(box, "Open settings — click the shortcut, then press a new combination.")
	_shortcut_button = Button.new()
	FGStyle.button(_shortcut_button)
	_shortcut_button.pressed.connect(func():
		_capture_shortcut = true
		_shortcut_button.text = _local("Press shortcut…")
		_shortcut_hint.text = _local("Use Ctrl or Alt with A–Z, 0–9 or F1–F12. Esc cancels.")
	)
	box.add_child(_shortcut_button)
	_shortcut_hint = _note(box, "Use Ctrl or Alt with A–Z, 0–9 or F1–F12. Esc cancels.")
	var restore := Button.new()
	restore.text = _local("Restore menu shortcut")
	FGStyle.button(restore)
	restore.pressed.connect(func():
		_capture_shortcut = false
		_menu_key = KEY_F9
		_menu_mods = FGShortcut.ALT
		_sync_extra_controls()
		_update_footer()
	)
	box.add_child(restore)
	box.add_child(HSeparator.new())
	_note(box, "HUD shortcuts (project defaults)")
	var key_name := OS.get_keycode_string(_key)
	_note(box, key_name + "  —  " + _local("Show / hide HUD"))
	_note(box, "Shift+" + key_name + "  —  " + _local("Cycle layout"))
	_note(box, "Ctrl+" + key_name + "  —  " + _local("Reset statistics"))
	_note(box, "Ctrl+Shift+" + key_name + "  —  " + _local("Reset position"))
	_note(box, "Alt + drag  —  " + _local("Move HUD"))
	_note(box, "Choose a shortcut not used by your game or OS.")

func _capture_key(event: InputEventKey) -> void:
	if event.keycode == KEY_ESCAPE:
		_capture_shortcut = false
		_sync_extra_controls()
		return
	if event.keycode in [KEY_CTRL, KEY_ALT, KEY_SHIFT, KEY_META]:
		return
	var mods := FGShortcut.modifiers(event)
	if event.meta_pressed or not FGShortcut.valid(int(event.keycode), mods, _key):
		_shortcut_hint.text = _local("Unavailable or reserved combination. Try another, or Esc.")
		return
	_menu_key = int(event.keycode)
	_menu_mods = mods
	_capture_shortcut = false
	_sync_extra_controls()
	_update_footer()

func _build_advanced_tab(tabs: TabContainer) -> void:
	var box := _settings_tab(tabs, "Advanced")
	_note(box, "Sampling and measurement")
	_advanced_number(box, "refresh", "HUD refresh (Hz)", 1.0, 10.0, 0.5)
	_advanced_number(box, "samples", "Statistics window (frames)", 120.0, 1200.0, 60.0)
	_advanced_number(box, "graph_frames", "Graph window (frames)", 30.0, 600.0, 30.0)
	var graph := _appearance_choice(box, "Graph", ["Frame time (ms)", "Instantaneous FPS"])
	_advanced_fields["graph_mode"] = graph
	graph.item_selected.connect(func(index: int):
		_graph_mode = index
		_apply_advanced()
	)
	var timing := CheckBox.new()
	timing.text = _local("Measure CPU / GPU render time")
	box.add_child(timing)
	_advanced_fields["timing"] = timing
	timing.toggled.connect(func(enabled: bool):
		_measure_render = enabled
		_apply_advanced()
	)
	_note(box, "Render timing is opt-in. Hardware counters depend on the OS and renderer.")
	var reset := Button.new()
	reset.text = _local("Reset statistics")
	FGStyle.button(reset)
	reset.pressed.connect(reset_stats)
	box.add_child(reset)
	_note(box, "Project startup, language, accent and editor telemetry are configured in the Godot dock.")

func _advanced_number(parent: VBoxContainer, id: String, title: String, low: float, high: float, step: float) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = _local(title)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	row.add_child(spin)
	_advanced_fields[id] = spin
	spin.value_changed.connect(func(value: float):
		match id:
			"refresh": _refresh = 1.0 / value
			"samples": _sample_count = int(value)
			"graph_frames": _graph_count = int(value)
		_apply_advanced()
	)

func _apply_advanced() -> void:
	if _stats.capacity != _sample_count:
		var old := _stats.samples(_sample_count)
		_stats = FGStats.new(_sample_count)
		for ms in old:
			_stats.push(ms)
	_graph.fps_mode = _graph_mode == 1
	_update_measurement()
	_update_values()

func _sync_extra_controls() -> void:
	if not is_instance_valid(_shortcut_button):
		return
	_shortcut_button.text = get_settings_shortcut()
	_shortcut_hint.text = _local("Use Ctrl or Alt with A–Z, 0–9 or F1–F12. Esc cancels.")
	(_advanced_fields["refresh"] as SpinBox).set_value_no_signal(1.0 / _refresh)
	(_advanced_fields["samples"] as SpinBox).set_value_no_signal(_sample_count)
	(_advanced_fields["graph_frames"] as SpinBox).set_value_no_signal(_graph_count)
	(_advanced_fields["graph_mode"] as OptionButton).select(_graph_mode)
	(_advanced_fields["timing"] as CheckBox).set_pressed_no_signal(_measure_render)

func _capture_settings() -> Dictionary:
	return {"scale": _scale_factor, "bg": _bg_opacity, "opacity": _hud_opacity, "mode": _mode, "corner": _corner, "selected": _selected.duplicate(), "custom": _custom_position, "position": _panel.position, "menu_key": _menu_key, "menu_mods": _menu_mods, "refresh": _refresh, "samples": _sample_count, "graph_count": _graph_count, "graph_mode": _graph_mode, "measure_render": _measure_render}

func _cancel_appearance() -> void:
	if not is_instance_valid(_appearance) or not _appearance.visible:
		return
	if not _snapshot.is_empty():
		_scale_factor = _snapshot["scale"]
		_bg_opacity = _snapshot["bg"]
		_hud_opacity = _snapshot["opacity"]
		_corner = _snapshot["corner"]
		_selected = _snapshot["selected"]
		_custom_position = _snapshot["custom"]
		_panel.position = _snapshot["position"]
		_menu_key = _snapshot["menu_key"]
		_menu_mods = _snapshot["menu_mods"]
		_refresh = _snapshot["refresh"]
		_sample_count = _snapshot["samples"]
		_graph_count = _snapshot["graph_count"]
		_graph_mode = _snapshot["graph_mode"]
		_measure_render = _snapshot["measure_render"]
		set_mode(_snapshot["mode"])
		_apply_advanced()
		_update_footer()
		_apply_appearance()
		_snapshot.clear()
	_close_appearance()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_us > 0:
		var ms := float(now - _last_us) / 1000.0
		_stats.push(ms)
		_elapsed += ms / 1000.0
	_last_us = now
	if _elapsed >= _refresh:
		_elapsed = fmod(_elapsed, _refresh)
		_update_values()

func _update_values() -> void:
	var started := Time.get_ticks_usec()
	if _wanted("fps") or _telemetry:
		_fps.text = str(Engine.get_frames_per_second())
	if _wanted("frame") or _telemetry:
		_frame.text = "%.2f ms" % _stats.latest() if _stats.count > 0 else "-- ms"
	if _wanted("average") or _telemetry:
		_average.text = "%.1f" % _stats.average_fps() if _stats.count > 0 else "--"
	if _wanted("low") or _telemetry:
		var low: float = _stats.one_percent_low()
		_low.text = "%.1f" % low if low > 0.0 else "--"
	if _wanted("graph"):
		_graph.set_samples(_stats.samples(_graph_count))
	if _wanted("memory"):
		_memory.text = _bytes(Performance.get_monitor(Performance.MEMORY_STATIC))
	if _wanted("vram"):
		_vram.text = _bytes(float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)))
	if (_wanted("host_ram") or _wanted("host_cpu") or _wanted("host_gpu")) and Time.get_ticks_msec() - _host_at >= 1000:
		_host_at = Time.get_ticks_msec()
		var host := _host.sample(_wanted("host_ram"), _wanted("host_cpu"), _wanted("host_gpu"))
		_host_ram.text = "%s / %s" % [_gib(int(host["ram_free"])), _gib(int(host["ram_total"]))] if int(host["ram_free"]) >= 0 and int(host["ram_total"]) > 0 else "N/A"
		_host_cpu.text = _percent(float(host["cpu"]))
		_host_gpu.text = _percent(float(host["gpu"]))
	if _wanted("calls") or _telemetry:
		_calls.text = _counter(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	if _wanted("nodes") or _telemetry:
		_nodes.text = str(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	if _wanted("primitives"):
		_primitives.text = _counter(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	if _wanted("objects"):
		_objects.text = _counter(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	if _wanted("process_time"):
		_process_time.text = _ms(1000.0 * Performance.get_monitor(Performance.TIME_PROCESS))
	if _wanted("physics_time") or _telemetry:
		_physics_time.text = _ms(1000.0 * Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
	if _wanted("cpu_render") or _telemetry:
		_cpu_render.text = _ms(RenderingServer.viewport_get_measured_render_time_cpu(_viewport_rid)) if _measure_render and _panel.visible else "Off"
	if _wanted("gpu_render") or _telemetry:
		_gpu_render.text = _ms(RenderingServer.viewport_get_measured_render_time_gpu(_viewport_rid)) if _measure_render and _panel.visible else "Off"
	if _telemetry and EngineDebugger.is_active() and Time.get_ticks_msec() - _telemetry_at >= 500:
		_telemetry_at = Time.get_ticks_msec()
		EngineDebugger.send_message("pft_benchmark:sample", [{"fps": _fps.text, "avg": _average.text, "frame": _frame.text, "low": _low.text, "cpu": _cpu_render.text, "gpu": _gpu_render.text, "physics": _physics_time.text, "calls": _calls.text, "nodes": _nodes.text}])
	if _wanted("range") or _wanted("spikes"):
		var data := _stats.samples()
		var slowest := 0.0
		var fastest := INF
		var spikes := 0
		for ms in data:
			slowest = maxf(slowest, ms)
			fastest = minf(fastest, ms)
			if ms > 33.333:
				spikes += 1
		_range.text = "%.0f / %.0f" % [1000.0 / slowest, 1000.0 / fastest] if slowest > 0.0 else "--"
		_spikes.text = str(spikes)
	if _wanted("active"):
		_active.text = "%d / %d" % [int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)), int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))]
	if _wanted("pairs"):
		_pairs.text = "%d / %d" % [int(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)), int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))]
	if _wanted("self_cost"):
		_self_cost.text = "%.3f ms" % _update_cost
	_update_cost = float(Time.get_ticks_usec() - started) / 1000.0

func _ms(value: float) -> String:
	return "%.2f ms" % value if is_finite(value) and value > 0.0 else "N/A"

func _accent() -> Color:
	return Color(_setting("accent_color", ACCENT))

func _local(value: String) -> String:
	if _lang != 1:
		return value
	var extra := {"Cancel": "Отмена", "Apply": "Применить", "Controls": "Управление", "Open settings — click the shortcut, then press a new combination.": "Нажмите на комбинацию и задайте новую.", "Press shortcut…": "Нажмите комбинацию…", "Use Ctrl or Alt with A–Z, 0–9 or F1–F12. Esc cancels.": "Ctrl или Alt с A–Z, 0–9 или F1–F12. Esc — отмена.", "Restore menu shortcut": "Вернуть Alt+F9", "HUD shortcuts (project defaults)": "Горячие клавиши HUD (по проекту)", "Show / hide HUD": "Показать / скрыть HUD", "Cycle layout": "Сменить режим", "Reset statistics": "Сбросить статистику", "Reset position": "Сбросить позицию", "Move HUD": "Переместить HUD", "Choose a shortcut not used by your game or OS.": "Выберите комбинацию, свободную в игре и ОС.", "Unavailable or reserved combination. Try another, or Esc.": "Комбинация недоступна. Выберите другую или Esc.", "Sampling and measurement": "Сбор данных и измерения", "HUD refresh (Hz)": "Обновление HUD (Гц)", "Statistics window (frames)": "Окно статистики (кадры)", "Graph window (frames)": "Окно графика (кадры)", "Frame time (ms)": "Время кадра (мс)", "Instantaneous FPS": "Мгновенный FPS", "Measure CPU / GPU render time": "Измерять время рендера CPU/GPU", "Render timing is opt-in. Hardware counters depend on the OS and renderer.": "Время рендера измеряется по запросу. Счётчики зависят от ОС и рендера.", "Project startup, language, accent and editor telemetry are configured in the Godot dock.": "Запуск, язык, цвет и телеметрия настраиваются в панели Godot.", "Defaults previewed. Save to keep them.": "Настройки проекта показаны. Сохраните для применения."}
	if extra.has(value):
		return str(extra[value])
	var settings_labels := {"Settings": "Настройки", "HUD settings": "Настройки HUD", "Hide": "Скрыть", "Appearance": "Внешний вид", "Metrics": "Показатели", "Layout": "Режим", "Position": "Положение", "Minimal": "Минимальный", "Standard": "Стандартный", "Full": "Полный", "Custom": "Свой", "Top left": "Слева сверху", "Top right": "Справа сверху", "Bottom left": "Слева снизу", "Bottom right": "Справа снизу", "Save & close": "Сохранить и закрыть", "Choose what the HUD shows. Changes select Custom.": "Выберите показатели. Изменения включают свой режим.", "Frame Statistics": "Кадры", "Memory & Hardware": "Память и оборудование", "Rendering": "Рендеринг", "Timing": "Время обработки", "Advanced": "Дополнительно", "Frame time": "Время кадра", "Average FPS": "Средний FPS", "1% Low": "1% Low", "Graph": "График", "Draw calls": "Вызовы рендера", "Render CPU time": "Время рендера CPU", "Render GPU time": "Время рендера GPU", "Min / max FPS": "Мин. / макс. FPS", "Frames > 33 ms": "Кадры > 33 мс", "Collision pairs 2D/3D": "Пары коллизий 2D/3D", "HUD update CPU time": "Время обновления HUD", "System information": "Информация о системе"}
	if settings_labels.has(value):
		return str(settings_labels[value])
	return str({"FRAME TIME": "КАДР", "AVG FPS": "СР. FPS", "1% LOW": "1% LOW", "Engine memory": "Память движка", "Video memory": "Видеопамять", "Host free / total RAM": "Своб. / всего ОЗУ", "Host CPU busy": "Загрузка CPU системы", "DRM GPU busy": "Загрузка GPU DRM", "Render draw calls": "Вызовы рендера", "Render primitives": "Примитивы", "Nodes": "Узлы", "Render objects": "Объекты рендера", "Process time": "Обработка", "Physics time": "Физика", "Render CPU": "Рендер CPU", "Render GPU": "Рендер GPU", "Min / Max FPS": "Мин. / макс. FPS", "Frames > 33ms": "Кадры > 33 мс", "Active bodies 2D/3D": "Активные тела 2D/3D", "Pairs 2D/3D": "Пары 2D/3D", "HUD update CPU": "Обновление HUD", "Mode": "режим", "Reset": "сброс", "Style": "вид", "HUD appearance": "Внешний вид HUD", "HUD size": "Размер HUD", "Background opacity": "Непрозрачность фона", "Overall HUD opacity": "Непрозрачность HUD", "Project defaults": "По проекту", "Save locally": "Сохранить", "Close": "Закрыть", "Changes preview instantly": "Изменения сразу видны", "Saved locally": "Сохранено локально", "Project defaults restored": "Настройки проекта восстановлены"}.get(value, value))

func _counter(kind: int) -> String:
	var value := RenderingServer.get_rendering_info(kind)
	return str(value) if value >= 0 else "N/A"

func _bytes(value: float) -> String:
	return "%.1f MiB" % (value / 1048576.0) if value > 0.0 else "N/A"

func _gib(value: int) -> String:
	return "%.1f GiB" % (float(value) / 1073741824.0) if value >= 0 else "N/A"

func _percent(value: float) -> String:
	return "%.1f%%" % value if value >= 0.0 else "N/A"
