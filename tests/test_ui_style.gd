extends SceneTree
const FGStyle = preload("res://addons/pft_benchmark/ui_style.gd")

func _initialize() -> void:
	var s := FGStyle.panel(Color("171e27"), FGStyle.LINE, 6, 8.0)
	assert(s.bg_color == Color("171e27"))
	assert(s.get_content_margin(SIDE_LEFT) == 8.0)
	var button := Button.new()
	FGStyle.button(button, true)
	assert(button.has_theme_stylebox_override("normal"))
	var slider := HSlider.new()
	FGStyle.slider(slider)
	assert(slider.has_theme_stylebox_override("slider"))
	button.free()
	slider.free()
	print("FrameGauge UI style smoke test passed")
	quit(0)
