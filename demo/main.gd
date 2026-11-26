extends Node2D

var _t := 0.0
var _density := 180
var _label: Label

func _ready() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var title := Label.new()
	title.text = "FRAMEGAUGE / 2D LAB"
	title.position = Vector2(30, 28)
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("e7edf6"))
	ui.add_child(title)
	_label = Label.new()
	_label.position = Vector2(30, 62)
	_label.add_theme_color_override("font_color", Color("a2aebf"))
	ui.add_child(_label)
	var slider := HSlider.new()
	slider.position = Vector2(30, 115)
	slider.size = Vector2(280, 30)
	slider.min_value = 0
	slider.max_value = 2000
	slider.step = 10
	slider.value = _density
	slider.value_changed.connect(_set_density)
	ui.add_child(slider)
	_set_density(_density)

func _set_density(value: float) -> void:
	_density = int(value)
	_label.text = "Animated elements: %d\nF9: toggle HUD  |  Shift+F9: switch mode" % _density

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var bounds := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, bounds), Color("10151e"))
	for i in range(_density):
		var f := float(i)
		var x := 35.0 + fposmod(f * 73.9 + _t * (18.0 + fposmod(f, 34.0)), maxf(1.0, bounds.x - 70.0))
		var y := 175.0 + fposmod(f * 41.7 + sin(_t + f) * 13.0, maxf(1.0, bounds.y - 210.0))
		var col := Color("81d6b4") if i % 5 == 0 else Color("334658")
		draw_rect(Rect2(Vector2(x, y), Vector2(8.0 + fposmod(f, 8.0), 8.0 + fposmod(f, 8.0))), col)
