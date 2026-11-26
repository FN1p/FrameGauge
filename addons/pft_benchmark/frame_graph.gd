extends Control

var _values := PackedFloat64Array()
const GRID := Color("343c48")
var fps_mode := false
var russian := false
var line_color := Color("81d6b4")
const GUIDE := Color("a78b59")
const FG := Color("a2aebf")

func set_samples(values: PackedFloat64Array) -> void:
	_values = values
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var plot := Rect2(32, 5, maxf(1.0, size.x - 37.0), maxf(1.0, size.y - 21.0))
	var ceiling := 60.0 if fps_mode else 33.333
	for ms in _values:
		ceiling = maxf(ceiling, 1000.0 / maxf(ms, 0.001) if fps_mode else ms)
	for i in range(3):
		var fraction := float(i) / 2.0
		var y := plot.position.y + plot.size.y * fraction
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), GRID)
		draw_string(font, Vector2(1, y + 4), "%.0f" % (ceiling * (1.0 - fraction)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, FG)
	var target_y := plot.end.y - (60.0 if fps_mode else 16.667) / ceiling * plot.size.y
	draw_line(Vector2(plot.position.x, target_y), Vector2(plot.end.x, target_y), GUIDE)
	if _values.size() >= 2:
		var points := PackedVector2Array()
		for i in range(_values.size()):
			var x := plot.position.x + plot.size.x * float(i) / float(_values.size() - 1)
			var value := 1000.0 / maxf(_values[i], 0.001) if fps_mode else _values[i]
			var y := plot.end.y - value / ceiling * plot.size.y
			points.append(Vector2(x, y))
		draw_polyline(points, line_color, 1.5, true)
	draw_string(font, Vector2(plot.position.x, size.y - 2), ("FPS" if fps_mode else "ms") + (" / %d кадров" if russian else " / last %d frames") % _values.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, FG)
