extends SceneTree
const FGHost = preload("res://addons/pft_benchmark/system_metrics.gd")

func _initialize() -> void:
	# Large totals must retain small differences even on single-precision Vector2 builds.
	var base: int = 900000000000
	var idle: int = 600000000000
	var checks := [
		is_equal_approx(FGHost.cpu_busy_percent(base, idle, base + 100, idle + 25), 75.0),
		is_equal_approx(FGHost.cpu_busy_percent(base, idle, base + 100, idle + 100), 0.0),
		is_equal_approx(FGHost.cpu_busy_percent(base, idle, base + 100, idle), 100.0),
		FGHost.cpu_busy_percent(-1, -1, base, idle) == -1.0,
		FGHost.cpu_busy_percent(base, idle, base, idle) == -1.0,
		FGHost.cpu_busy_percent(base, idle, base + 10, idle + 11) == -1.0,
		FGHost.cpu_busy_percent(base, idle, base + 10, idle - 1) == -1.0,
	]
	if checks.has(false):
		push_error("Host counter validation failed")
		quit(1)
		return
	print("Host counter checks passed")
	quit(0)
