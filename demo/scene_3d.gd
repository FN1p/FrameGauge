extends Node3D
## Interactive 3D lab. Real rigid bodies and separate render-only geometry.
const FGStyle = preload("res://addons/pft_benchmark/ui_style.gd")
const COUNTS := [0, 64, 256, 512, 1024]
const RENDER_COUNTS := [0, 100, 400, 900, 1600]
var _bodies: Node3D
var _geometry: Node3D
var _sun: DirectionalLight3D
var _camera: Camera3D
var _status: Label
var _result: Label
var _physics_select: OptionButton
var _render_select: OptionButton
var _shadow: CheckButton
var _cap: CheckButton
var _ab: Button
var _hud_settings: Button
var _preset: OptionButton
var _run: Button
var _cancel := false
var _controls: Array[Control] = []
var _rng := RandomNumberGenerator.new()
var _box_mesh := BoxMesh.new()
var _ball_mesh := SphereMesh.new()
var _box_shape := BoxShape3D.new()
var _ball_shape := SphereShape3D.new()
var _materials: Array[StandardMaterial3D] = []
var _render_mesh := TorusMesh.new()
var _testing := false
var _angle := 0.0
var _orbit := false
var _overlay: Node
var _fps_before := 0.0
var _fps_after := 0.0
var _previous_max_fps: int
var _previous_vsync: DisplayServer.VSyncMode

func _ready() -> void:
	_previous_max_fps = Engine.max_fps
	_previous_vsync = DisplayServer.window_get_vsync_mode()
	_overlay = get_node_or_null("/root/PFTBenchmark")
	_build_world()
	_build_controls()
	_set_uncapped(false)
	_rebuild()

func _mat(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = 0.48
	return m

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("182332")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("afc9e0")
	e.ambient_light_energy = 0.65
	env.environment = e
	add_child(env)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-56, -30, 0)
	_sun.light_energy = 1.2
	_sun.shadow_enabled = true
	add_child(_sun)
	_camera = Camera3D.new()
	_camera.fov = 51.0
	add_child(_camera)
	_camera.current = true
	_place_camera()
	var floor_mat := _mat(Color("344555"))
	var wall_mat := _mat(Color("526778"))
	_static_box(Vector3(0,-0.55,0), Vector3(23,1,23), floor_mat)
	_static_box(Vector3(-11.5,0.7,0), Vector3(0.35,2.5,23), wall_mat)
	_static_box(Vector3(11.5,0.7,0), Vector3(0.35,2.5,23), wall_mat)
	_static_box(Vector3(0,0.7,-11.5), Vector3(23,2.5,0.35), wall_mat)
	_static_box(Vector3(0,0.3,11.5), Vector3(23,1.7,0.35), wall_mat)
	for x in range(-9, 10, 6):
		_static_box(Vector3(x,0.4,-1), Vector3(1.5,0.8,5), wall_mat)
	_box_mesh.size = Vector3.ONE * 0.6
	_box_shape.size = _box_mesh.size
	_ball_mesh.radius = 0.3
	_ball_mesh.height = 0.6
	_ball_mesh.radial_segments = 16
	_ball_mesh.rings = 8
	_ball_shape.radius = 0.3
	for color in [Color("80d6b4"), Color("c9995f"), Color("6f95c1"), Color("d8e1e9")]:
		_materials.append(_mat(color, 0.15))
	_render_mesh.inner_radius = 0.19
	_render_mesh.outer_radius = 0.48
	_render_mesh.rings = 24
	_render_mesh.ring_segments = 16
	_render_mesh.material = _mat(Color("7296bd"), 0.65)
	_bodies = Node3D.new()
	add_child(_bodies)
	_geometry = Node3D.new()
	add_child(_geometry)

func _static_box(pos: Vector3, extent: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	body.position = pos
	var mesh := BoxMesh.new()
	mesh.size = extent
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	body.add_child(visual)
	var shape := BoxShape3D.new()
	shape.size = extent
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

func _place_camera() -> void:
	_camera.position = Vector3(sin(_angle + 0.6) * 36, 28, cos(_angle + 0.6) * 36)
	_camera.look_at(Vector3(0, 2, -4))

func _build_controls() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 5
	add_child(canvas)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 10)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	canvas.add_child(scroll)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", FGStyle.panel(Color(0.075, 0.10, 0.13, 0.93), FGStyle.LINE, 7, 9.0))
	scroll.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 208
	box.add_theme_constant_override("separation",4)
	panel.add_child(box)
	var title := Label.new()
	title.text = "FRAMEGAUGE / 3D LAB"
	title.add_theme_color_override("font_color", Color("81d6b4"))
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Physics & rendering stress test"
	box.add_child(subtitle)
	_hud_settings = _button(box, "HUD settings / size", func():
		if _monitor_available():
			_overlay.call("open_settings")
	)
	_hud_settings.disabled = not _monitor_available()
	_controls.append(_hud_settings)
	var preset_label := Label.new()
	preset_label.text = "Workload preset"
	box.add_child(preset_label)
	_preset = OptionButton.new()
	for item in ["Custom", "Low", "Medium", "High", "Extreme"]:
		_preset.add_item(item)
	_preset.select(0)
	box.add_child(_preset)
	_controls.append(_preset)
	_preset.item_selected.connect(_apply_preset)
	_physics_select = _option(box, "Rigid bodies (real collisions)", COUNTS, 2)
	_render_select = _option(box, "Render-only torus meshes", RENDER_COUNTS, 1)
	_shadow = CheckButton.new()
	_shadow.text = "Dynamic shadows"
	_shadow.button_pressed = true
	_shadow.toggled.connect(func(on: bool):
		_sun.shadow_enabled = on
		_preset.select(0)
	)
	box.add_child(_shadow)
	_controls.append(_shadow)
	_cap = CheckButton.new()
	_cap.text = "Uncap FPS / disable VSync"
	_cap.toggled.connect(_set_uncapped)
	box.add_child(_cap)
	_controls.append(_cap)
	var rebuild := _button(box,"Reset / drop bodies",_rebuild)
	_controls.append(rebuild)
	var impulse := _button(box,"Blast / wake bodies",_blast)
	_controls.append(impulse)
	var orbit := _button(box,"Toggle orbit camera",func(): _orbit = not _orbit)
	_controls.append(orbit)
	_ab = _button(box,"Measure HUD cost (A/B)",_run_ab)
	_controls.append(_ab)
	_run = _button(box, "60s workload benchmark", _run_benchmark)
	_controls.append(_run)
	_status = Label.new()
	_status.add_theme_color_override("font_color",Color("a2aebf"))
	box.add_child(_status)
	_result = Label.new()
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.custom_minimum_size.x = 208
	_result.text = "F9: HUD | Shift+F9: mode\nCtrl+F9: reset stats\nAlt+drag: move HUD\nHUD settings button or configured shortcut"
	box.add_child(_result)
	if not _monitor_available():
		_ab.disabled = true
	var resize := func():
		var view := get_viewport().get_visible_rect().size
		var natural := panel.get_combined_minimum_size()
		scroll.size = Vector2(minf(natural.x + 14.0, maxf(1.0, view.x - 20.0)), minf(natural.y, maxf(1.0, view.y - 20.0)))
	get_viewport().size_changed.connect(resize)
	panel.minimum_size_changed.connect(resize)
	resize.call_deferred()

func _button(parent: VBoxContainer, caption: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = caption
	FGStyle.button(b, caption.begins_with("60s") or caption.begins_with("Reset"))
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func _option(parent: VBoxContainer, caption: String, values: Array, initial: int) -> OptionButton:
	var l := Label.new()
	l.text = caption
	parent.add_child(l)
	var option := OptionButton.new()
	for i in range(values.size()):
		option.add_item(str(values[i]),i)
	option.select(initial)
	option.item_selected.connect(func(_index: int):
		_preset.select(0)
		_rebuild()
	)
	parent.add_child(option)
	_controls.append(option)
	return option

func _set_uncapped(on: bool) -> void:
	Engine.max_fps = 0 if on else 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED if on else DisplayServer.VSYNC_ENABLED)

func _rebuild() -> void:
	if _testing:
		return
	for root in [_bodies, _geometry]:
		for child in root.get_children():
			root.remove_child(child)
			child.queue_free()
	_rng.seed = 104729
	var body_count := int(COUNTS[_physics_select.selected])
	var mesh_count := int(RENDER_COUNTS[_render_select.selected])
	for i in range(body_count):
		var body := RigidBody3D.new()
		var ball := i % 3 == 0
		body.can_sleep = true
		var collision := CollisionShape3D.new()
		collision.shape = _ball_shape if ball else _box_shape
		body.add_child(collision)
		var visual := MeshInstance3D.new()
		visual.mesh = _ball_mesh if ball else _box_mesh
		visual.material_override = _materials[i % _materials.size()]
		body.add_child(visual)
		var cell := i % 225
		body.position = Vector3(float(cell % 15 - 7) * 1.22, 3.0 + floorf(float(i) / 225.0) * 1.1, (floorf(float(cell) / 15.0) - 7.0) * 1.22)
		body.rotation = Vector3(_rng.randf(),_rng.randf(),_rng.randf())
		_bodies.add_child(body)
	for i in range(mesh_count):
		var item := MeshInstance3D.new()
		item.mesh = _render_mesh
		var col := i % 40
		var row := floori(float(i) / 40.0)
		item.position = Vector3(float(col % 20 - 10) * 1.05, 0.6 + float(row % 8) * 1.05, -13.0 - floorf(float(col) / 20.0) * 1.2 - floorf(float(row) / 8.0) * 1.15)
		item.rotation_degrees = Vector3(65, float(i % 12) * 30, 0)
		_geometry.add_child(item)
	_status.text = "%d bodies / %d meshes" % [body_count, mesh_count]
	if is_instance_valid(_overlay):
		_overlay.call("reset_stats")

func _blast() -> void:
	for child in _bodies.get_children():
		var body := child as RigidBody3D
		body.sleeping = false
		body.apply_central_impulse(Vector3(_rng.randf_range(-4,4),_rng.randf_range(3,7),_rng.randf_range(-4,4)))

func _process(delta: float) -> void:
	if _orbit and not _testing:
		_angle += delta * 0.25
		_place_camera()

func _monitor_available() -> bool:
	return is_instance_valid(_overlay) and _overlay.has_method("is_monitor_available") and bool(_overlay.call("is_monitor_available"))

func _run_ab() -> void:
	if _testing or not _monitor_available():
		return
	if not _cap.button_pressed or Engine.max_fps != 0 or DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED:
		_result.text = "Enable Uncap FPS first for an A/B test."
		return
	_testing = true
	for control in _controls:
		if control is BaseButton:
			control.disabled = true
	# Freeze identical transforms; isolate HUD rather than changing physics workload.
	var previous: Array[bool] = []
	for child in _bodies.get_children():
		var body := child as RigidBody3D
		previous.append(body.freeze)
		body.freeze = true
	var was_visible := bool(_overlay.call("is_overlay_visible"))
	_overlay.call("set_input_locked", true)
	_overlay.call("set_overlay_visible", false)
	_result.text = "A/B: HUD off / warm-up 2s"
	await get_tree().create_timer(2.0).timeout
	_result.text = "A/B: HUD off / measuring 5s"
	_fps_before = await _sample_fps(5.0)
	_overlay.call("set_overlay_visible", true)
	_result.text = "A/B: HUD on / warm-up 2s"
	await get_tree().create_timer(2.0).timeout
	_result.text = "A/B: HUD on / measuring 5s"
	_fps_after = await _sample_fps(5.0)
	_overlay.call("set_overlay_visible", was_visible)
	_overlay.call("set_input_locked", false)
	var i := 0
	for child in _bodies.get_children():
		(child as RigidBody3D).freeze = previous[i]
		i += 1
	for control in _controls:
		if control is BaseButton:
			control.disabled = false
	_ab.disabled = not _monitor_available()
	_hud_settings.disabled = not _monitor_available()
	_testing = false
	_result.text = "HUD off: %.1f FPS\nHUD on: %.1f FPS\nFrame delta: %+.3f ms\nStatic scene; repeat uncapped." % [_fps_before, _fps_after, 1000.0/maxf(_fps_after,0.001)-1000.0/maxf(_fps_before,0.001)]

func _sample_fps(seconds: float) -> float:
	var start := Time.get_ticks_usec()
	var frames := 0
	while float(Time.get_ticks_usec() - start) < seconds * 1000000.0:
		await get_tree().process_frame
		frames += 1
	return float(frames) * 1000000.0 / maxf(1.0, float(Time.get_ticks_usec() - start))

func _apply_preset(index: int) -> void:
	if _testing or index == 0:
		return
	_physics_select.select(index)
	_render_select.select(index)
	_shadow.set_pressed_no_signal(index >= 3)
	_sun.shadow_enabled = index >= 3
	_rebuild()

func _run_benchmark() -> void:
	if _testing:
		_cancel = true
		return
	if not _cap.button_pressed or Engine.max_fps != 0 or DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED:
		_result.text = "Enable Uncap FPS first for an uncapped workload test."
		return
	_rebuild()
	_testing = true
	_cancel = false
	for control in _controls:
		if control is BaseButton:
			(control as BaseButton).disabled = true
	_run.disabled = false
	_run.text = "Cancel benchmark"
	if is_instance_valid(_overlay):
		_overlay.call("set_input_locked", true)
	_result.text = "Warm-up · 3 seconds"
	await get_tree().create_timer(3.0).timeout
	var data := PackedFloat64Array()
	var begin := Time.get_ticks_usec()
	var previous := begin
	var next_blast := begin
	var next_ui := begin
	var frames := 0
	var spikes := 0
	var elapsed := 0.0
	# Impulse every five seconds keeps physics active. Camera is stationary.
	while not _cancel and elapsed < 60.0:
		var now := Time.get_ticks_usec()
		if now >= next_blast:
			_blast()
			next_blast = now + 5000000
		if now >= next_ui:
			_result.text = "Workload test · %02d / 60 s\nPeriodic physics impulses" % int(elapsed)
			next_ui = now + 1000000
		await get_tree().process_frame
		now = Time.get_ticks_usec()
		var ms := float(now - previous) / 1000.0
		previous = now
		elapsed = float(now - begin) / 1000000.0
		if ms > 0.0:
			frames += 1
			if data.size() < 200000:
				data.append(ms)
			if ms > 33.333:
				spikes += 1
	if _cancel:
		_result.text = "Benchmark cancelled."
	elif frames > 0 and elapsed > 0.0:
		var low_text := "N/A"
		if data.size() == frames and frames >= 100:
			data.sort()
			var n := maxi(1, ceili(float(frames) * 0.01))
			var total := 0.0
			for i in range(frames - n, frames):
				total += data[i]
			if total > 0.0:
				low_text = "%.1f" % (1000.0 * n / total)
		_result.text = "60s result · %.1f FPS avg\n1%% Low: %s FPS\nFrames > 33.3 ms: %d\n%d frames / %.1f s" % [float(frames) / elapsed, low_text, spikes, frames, elapsed]
	else:
		_result.text = "No frame samples."
	if is_instance_valid(_overlay):
		_overlay.call("set_input_locked", false)
	for control in _controls:
		if control is BaseButton:
			(control as BaseButton).disabled = false
	_ab.disabled = not _monitor_available()
	_hud_settings.disabled = not _monitor_available()
	_run.text = "60s workload benchmark"
	_testing = false

func _exit_tree() -> void:
	Engine.max_fps = _previous_max_fps
	DisplayServer.window_set_vsync_mode(_previous_vsync)
	if is_instance_valid(_overlay):
		_overlay.call("set_input_locked", false)
