@tool
extends VBoxContainer
## Project settings are applied explicitly, not on every widget change.
const FGMetrics = preload("res://addons/pft_benchmark/metric_config.gd")
const FGStyle = preload("res://addons/pft_benchmark/ui_style.gd")
const FGShortcut = preload("res://addons/pft_benchmark/shortcut_config.gd")
var _menu_key_choice: OptionButton
var _menu_mod_choice: OptionButton
const PREFIX := "pft_benchmark/"
var _fields := {}
var _defaults := {}
var _status: Label
var _live: Label
var _live_status: Label
var _last_sample := 0
var _last_session := -1
var _metric_count: Label
var _preview: PanelContainer
var _preview_base: Control
var _preview_brand: Label
var _preview_fps: Label
var _slider_labels := {}

func build(defaults: Dictionary) -> void:
	_defaults = defaults.duplicate()
	name = "FrameGauge"
	add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "FrameGauge"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("81d6b4"))
	add_child(title)
	var sub := Label.new()
	sub.text = "Performance monitor  /  Free 0.8.0"
	sub.add_theme_color_override("font_color", FGStyle.MUTED)
	sub.add_theme_font_size_override("font_size", 11)
	add_child(sub)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)
	var fields := _tab(tabs, "Setup")
	_section(fields, "GENERAL")
	_check(fields, "enabled", "Enable runtime monitor")
	_check(fields, "show_on_start", "Show HUD on start")
	_check(fields, "allow_release", "Allow in release exports")
	_check(fields, "editor_telemetry", "Send live metrics to editor (debug only)")
	fields = _tab(tabs, "Style")
	_section(fields, "APPEARANCE")
	_choice(fields, "mode", "Layout", ["Minimal", "Standard", "Full", "Custom"])
	(_fields["mode"] as OptionButton).item_selected.connect(func(_index: int): _update_metric_count())
	_choice(fields, "corner", "Corner", ["Top left", "Top right", "Bottom left", "Bottom right"])
	_choice(fields, "language", "HUD language", ["English", "Русский"])
	_slider(fields, "scale", "HUD size", 0.4, 2.0, 0.05)
	var sizes := HBoxContainer.new()
	fields.add_child(sizes)
	for factor in [0.5, 0.75, 1.0]:
		var b := Button.new()
		b.text = "%d%%" % roundi(factor * 100.0)
		FGStyle.button(b)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_quick_size.bind(factor))
		sizes.add_child(b)
	_slider(fields, "opacity", "Background opacity", 0.0, 1.0, 0.05)
	_slider(fields, "hud_opacity", "Overall HUD opacity", 0.35, 1.0, 0.05)
	_build_preview(fields)
	_caption(fields, "Accent color")
	var color := ColorPickerButton.new()
	color.edit_alpha = false
	color.custom_minimum_size.y = 30
	fields.add_child(color)
	_fields["accent_color"] = color
	color.color_changed.connect(func(_c: Color): _refresh_preview())
	_section(fields, "SAMPLING")
	_number(fields, "refresh_hz", "HUD refresh (Hz)", 1.0, 10.0, 0.5)
	_number(fields, "sample_count", "Statistics window (frames)", 120, 1200, 60)
	_number(fields, "graph_frames", "Graph window (frames)", 30, 600, 30)
	_choice(fields, "graph_mode", "Graph", ["Frame time (ms)", "Instantaneous FPS"])
	_check(fields, "measure_render_time", "Measure CPU / GPU render time (opt-in)")
	fields = _tab(tabs, "Metrics")
	_caption(fields, "Choose individual HUD metrics")
	_metric_count = Label.new()
	fields.add_child(_metric_count)
	var presets := HBoxContainer.new()
	fields.add_child(presets)
	for i in range(3):
		var b := Button.new()
		b.text = ["Min", "Std", "Full"][i]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		FGStyle.button(b)
		b.pressed.connect(_select_preset.bind(i))
		presets.add_child(b)
	for group in FGMetrics.GROUPS:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", FGStyle.panel(Color("1c232c"), FGStyle.LINE, 6, 7.0))
		fields.add_child(card)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 3)
		card.add_child(content)
		var group_buttons := HBoxContainer.new()
		content.add_child(group_buttons)
		var heading := Label.new()
		heading.text = str(group).capitalize()
		heading.add_theme_color_override("font_color", FGStyle.ACCENT)
		heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		group_buttons.add_child(heading)
		for enabled in [true, false]:
			var b := Button.new()
			b.text = "All" if enabled else "None"
			FGStyle.button(b)
			b.pressed.connect(_select_group.bind(group, enabled))
			group_buttons.add_child(b)
		for id in FGMetrics.GROUPS[group]:
			_check(content, "metric_" + id, FGMetrics.METRICS[id][0])
			(_fields["metric_" + id] as CheckBox).toggled.connect(_metric_changed)
	var note := Label.new()
	note.text = "Editing metrics selects Custom layout. Render timing needs the opt-in in Style. N/A means unavailable. Apply & restart game."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fields.add_child(note)
	fields = _tab(tabs, "Controls")
	_section(fields, "OPEN SETTINGS")
	_caption(fields, "Modifier combination")
	_menu_mod_choice = OptionButton.new()
	for flags in [1, 2, 3, 5, 6, 7]:
		_menu_mod_choice.add_item(FGShortcut.text(KEY_F9, flags).trim_suffix("+F9"), flags)
	fields.add_child(_menu_mod_choice)
	_caption(fields, "Key")
	_menu_key_choice = OptionButton.new()
	for key in range(KEY_F1, KEY_F12 + 1):
		_menu_key_choice.add_item(OS.get_keycode_string(key), key)
	for key in range(KEY_A, KEY_Z + 1):
		_menu_key_choice.add_item(OS.get_keycode_string(key), key)
	for key in range(KEY_0, KEY_9 + 1):
		_menu_key_choice.add_item(OS.get_keycode_string(key), key)
	fields.add_child(_menu_key_choice)
	var controls_note := Label.new()
	controls_note.text = "Apply & save, then restart. In-game Controls can override this shortcut locally. Choose a combination not used by your game or OS."
	controls_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fields.add_child(controls_note)
	fields = _tab(tabs, "Live")
	_live_status = Label.new()
	_live_status.text = "Live game: waiting for debug session"
	_live_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fields.add_child(_live_status)
	_live = Label.new()
	_live.text = "Enable editor telemetry in Setup, then run F5."
	_live.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fields.add_child(_live)
	var buttons := HBoxContainer.new()
	add_child(buttons)
	var apply := Button.new()
	apply.text = "Apply & save"
	FGStyle.button(apply, true)
	apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply.pressed.connect(_apply)
	buttons.add_child(apply)
	var reset := Button.new()
	reset.text = "Defaults"
	FGStyle.button(reset)
	reset.pressed.connect(func():
		_load_fields(true)
		_status.text = "Defaults staged. Apply to save."
	)
	buttons.add_child(reset)
	var reload := Button.new()
	reload.text = "Reload"
	FGStyle.button(reload)
	reload.pressed.connect(func():
		_load_fields(false)
		_status.text = "Loaded saved project settings."
	)
	buttons.add_child(reload)
	_status = Label.new()
	_status.text = "Style: size & position. Metrics: what to show. Apply & save, then restart. In-game: Settings button or configured shortcut."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	_load_fields(false)
	tabs.current_tab = 1
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_check_live)
	add_child(timer)

func _quick_size(factor: float) -> void:
	(_fields["scale"] as HSlider).value = factor

func _tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var fields := VBoxContainer.new()
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_theme_constant_override("separation", 5)
	scroll.add_child(fields)
	return fields

func _metric_changed(_enabled: bool) -> void:
	(_fields["mode"] as OptionButton).select(3)
	_update_metric_count()

func _select_group(group: String, enabled: bool) -> void:
	for id in FGMetrics.GROUPS[group]:
		(_fields["metric_" + id] as CheckBox).set_pressed_no_signal(enabled)
	_metric_changed(enabled)

func _select_preset(mode: int) -> void:
	for id in FGMetrics.METRICS:
		(_fields["metric_" + id] as CheckBox).set_pressed_no_signal(FGMetrics.visible_in_mode(id, mode))
	(_fields["mode"] as OptionButton).select(mode)
	_update_metric_count()

func _update_metric_count() -> void:
	var enabled := 0
	var visible_count := 0
	var mode: int = (_fields["mode"] as OptionButton).selected
	for id in FGMetrics.METRICS:
		if (_fields["metric_" + id] as CheckBox).button_pressed:
			enabled += 1
			if FGMetrics.visible_in_mode(id, mode):
				visible_count += 1
	_metric_count.text = "%d selected · %d visible" % [enabled, visible_count]

func _caption(parent: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	parent.add_child(l)

func _section(parent: VBoxContainer, text: String) -> void:
	parent.add_child(HSeparator.new())
	_caption(parent, text)

func _check(parent: VBoxContainer, key: String, text: String) -> void:
	var c := CheckBox.new()
	c.text = text
	parent.add_child(c)
	_fields[key] = c

func _choice(parent: VBoxContainer, key: String, text: String, choices: Array) -> void:
	_caption(parent, text)
	var o := OptionButton.new()
	for choice in choices:
		o.add_item(str(choice))
	parent.add_child(o)
	_fields[key] = o

func _number(parent: VBoxContainer, key: String, text: String, low: float, high: float, step: float) -> void:
	_caption(parent, text)
	var s := SpinBox.new()
	s.min_value = low
	s.max_value = high
	s.step = step
	parent.add_child(s)
	_fields[key] = s

func _slider(parent: VBoxContainer, key: String, caption: String, low: float, high: float, step: float) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var name_label := Label.new()
	name_label.text = caption
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var readout := Label.new()
	readout.add_theme_color_override("font_color", FGStyle.ACCENT)
	row.add_child(readout)
	var slider_node := HSlider.new()
	slider_node.min_value = low
	slider_node.max_value = high
	slider_node.step = step
	FGStyle.slider(slider_node)
	parent.add_child(slider_node)
	_fields[key] = slider_node
	_slider_labels[key] = readout
	slider_node.value_changed.connect(func(value: float):
		readout.text = "%d%%" % roundi(value * 100.0)
		_refresh_preview()
	)

func _build_preview(parent: VBoxContainer) -> void:
	_caption(parent, "HUD preview  /  sample data")
	var background := PanelContainer.new()
	background.add_theme_stylebox_override("panel", FGStyle.panel(Color("303c49"), FGStyle.LINE, 6, 0.0))
	background.custom_minimum_size.y = 154.0
	parent.add_child(background)
	_preview_base = Control.new()
	_preview_base.clip_contents = true
	background.add_child(_preview_base)
	_preview = PanelContainer.new()
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_base.add_child(_preview)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 180.0
	_preview.add_child(content)
	_preview_brand = Label.new()
	_preview_brand.text = "FrameGauge"
	_preview_brand.add_theme_font_size_override("font_size", 10)
	content.add_child(_preview_brand)
	_preview_fps = Label.new()
	_preview_fps.text = "120 FPS   /   8.33 ms"
	_preview_fps.add_theme_font_size_override("font_size", 16)
	content.add_child(_preview_fps)
	var detail := Label.new()
	detail.text = "1% Low  87   ·   Preview"
	detail.add_theme_color_override("font_color", FGStyle.MUTED)
	content.add_child(detail)
	_preview_base.resized.connect(_refresh_preview)

func _refresh_preview() -> void:
	if not is_instance_valid(_preview) or not _fields.has("accent_color"):
		return
	var factor: float = (_fields["scale"] as HSlider).value
	var bg: Color = FGStyle.SURFACE
	bg.a = (_fields["opacity"] as HSlider).value
	var border: Color = FGStyle.LINE
	border.a = bg.a
	_preview.add_theme_stylebox_override("panel", FGStyle.panel(bg, border, 6, 7.0))
	_preview.modulate.a = (_fields["hud_opacity"] as HSlider).value
	var accent: Color = (_fields["accent_color"] as ColorPickerButton).color
	_preview_brand.add_theme_color_override("font_color", accent)
	_preview_fps.add_theme_color_override("font_color", accent)
	_preview.reset_size()
	var fit := minf(factor, minf(maxf(1.0, _preview_base.size.x - 16.0) / maxf(1.0, _preview.size.x), maxf(1.0, _preview_base.size.y - 16.0) / maxf(1.0, _preview.size.y)))
	_preview.scale = Vector2.ONE * fit
	_preview.position = (_preview_base.size - _preview.size * fit) * 0.5

func _load_fields(use_defaults: bool) -> void:
	for key in _fields:
		var node: Control = _fields[key]
		var value: Variant = _defaults[key] if use_defaults else ProjectSettings.get_setting(PREFIX + key, _defaults[key])
		if node is CheckBox:
			(node as CheckBox).set_pressed_no_signal(bool(value))
		elif node is OptionButton:
			(node as OptionButton).select(clampi(int(value), 0, (node as OptionButton).item_count - 1))
		elif node is SpinBox:
			(node as SpinBox).value = float(value)
		elif node is HSlider:
			(node as HSlider).set_value_no_signal(float(value))
			(_slider_labels[key] as Label).text = "%d%%" % roundi((node as HSlider).value * 100.0)
		elif node is ColorPickerButton:
			(node as ColorPickerButton).color = Color(value)

	var key := int(_defaults["settings_key"] if use_defaults else ProjectSettings.get_setting(PREFIX + "settings_key", _defaults["settings_key"]))
	var mods := int(_defaults["settings_modifiers"] if use_defaults else ProjectSettings.get_setting(PREFIX + "settings_modifiers", _defaults["settings_modifiers"]))
	var toggle := int(ProjectSettings.get_setting(PREFIX + "toggle_key", KEY_F9))
	if not FGShortcut.valid(key, mods, toggle):
		key = KEY_F9
		mods = FGShortcut.ALT
	_menu_key_choice.select(_menu_key_choice.get_item_index(key))
	_menu_mod_choice.select(_menu_mod_choice.get_item_index(mods))
	_update_metric_count()
	_refresh_preview.call_deferred()

func _apply() -> void:
	var menu_key := _menu_key_choice.get_selected_id()
	var menu_mods := _menu_mod_choice.get_selected_id()
	if not FGShortcut.valid(menu_key, menu_mods, int(ProjectSettings.get_setting(PREFIX + "toggle_key", KEY_F9))):
		_status.text = "Reserved settings shortcut. Choose another combination in Controls."
		return
	ProjectSettings.set_setting(PREFIX + "settings_key", menu_key)
	ProjectSettings.set_setting(PREFIX + "settings_modifiers", menu_mods)
	for key in _fields:
		var node: Control = _fields[key]
		var value: Variant = _defaults[key]
		if node is CheckBox:
			value = (node as CheckBox).button_pressed
		elif node is OptionButton:
			value = (node as OptionButton).selected
		elif node is SpinBox:
			value = int((node as SpinBox).value) if typeof(_defaults[key]) == TYPE_INT else (node as SpinBox).value
		elif node is HSlider:
			value = (node as HSlider).value
		elif node is ColorPickerButton:
			value = (node as ColorPickerButton).color
		ProjectSettings.set_setting(PREFIX + key, value)
	ProjectSettings.set_setting(PREFIX + "compact", false)
	var error := ProjectSettings.save()
	_status.text = "Saved. Restart game. Locally saved HUD style takes precedence." if error == OK else "Save failed (error %d)." % error

func receive_sample(session_id: int, sample: Dictionary) -> void:
	_last_sample = Time.get_ticks_msec()
	_last_session = session_id
	_live_status.text = "Live game · debug session %d" % session_id
	_live.text = "FPS  %s    Avg  %s\nFrame  %s    1%% Low  %s\nRender CPU  %s  |  GPU  %s\nPhysics  %s\nDraw calls  %s  |  Nodes  %s" % [str(sample.get("fps", "--")), str(sample.get("avg", "--")), str(sample.get("frame", "--")), str(sample.get("low", "--")), str(sample.get("cpu", "--")), str(sample.get("gpu", "--")), str(sample.get("physics", "--")), str(sample.get("calls", "--")), str(sample.get("nodes", "--"))]

func _check_live() -> void:
	if _last_sample > 0 and Time.get_ticks_msec() - _last_sample > 3000:
		_live_status.text = "No live data · last session %d" % _last_session
		_live.text = "HUD hidden, game paused/stopped, or telemetry unavailable."
