@tool
extends RefCounted

const INK := Color("e4e9ee")
const MUTED := Color("99a5b2")
const ACCENT := Color("81d6b4")
const SURFACE := Color("141a22")
const LINE := Color("303943")

static func panel(bg: Color, border: Color, radius: int = 6, margin: float = 8.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		s.set_content_margin(side, margin)
	return s

static func button(b: Button, primary: bool = false) -> void:
	var base := ACCENT if primary else Color("222a33")
	b.add_theme_stylebox_override("normal", panel(base, base if primary else LINE, 5, 5.0))
	b.add_theme_stylebox_override("hover", panel(base.lightened(0.10), ACCENT, 5, 5.0))
	b.add_theme_stylebox_override("pressed", panel(base.darkened(0.12), ACCENT, 5, 5.0))
	b.add_theme_color_override("font_color", SURFACE if primary else INK)
	b.add_theme_color_override("font_hover_color", SURFACE if primary else INK)
	b.add_theme_color_override("font_pressed_color", SURFACE if primary else INK)
	b.custom_minimum_size.y = 28.0

static func slider(slider_node: HSlider) -> void:
	var track := panel(Color("303943"), Color.TRANSPARENT, 3, 2.0)
	var fill := panel(ACCENT, Color.TRANSPARENT, 3, 2.0)
	slider_node.add_theme_stylebox_override("slider", track)
	slider_node.add_theme_stylebox_override("grabber_area", fill)
	slider_node.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider_node.custom_minimum_size.y = 24.0
