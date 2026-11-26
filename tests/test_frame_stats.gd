extends SceneTree

const FGStats = preload("res://addons/pft_benchmark/frame_stats.gd")
var failures := 0

func _initialize() -> void:
	var ring = FGStats.new(4)
	_check(ring.count == 0 and ring.average_fps() == 0.0, "empty")
	for n in [10.0, 20.0, 30.0, 40.0, 50.0]:
		ring.push(n)
	_check(ring.count == 4, "capacity")
	_check(ring.samples() == PackedFloat64Array([20.0, 30.0, 40.0, 50.0]), "wrap order")
	_check(is_equal_approx(ring.average_fps(), 1000.0 / 35.0), "average FPS")
	_check(ring.latest() == 50.0, "latest")
	_check(ring.samples(2) == PackedFloat64Array([40.0, 50.0]), "limited samples")
	ring.push(0.0)
	ring.push(-1.0)
	ring.push(INF)
	_check(ring.latest() == 50.0, "reject invalid intervals")
	ring.clear()
	_check(ring.count == 0 and ring.latest() == 0.0 and ring.one_percent_low() == 0.0, "clear")
	var lows = FGStats.new(200)
	for i in range(198):
		lows.push(10.0)
	lows.push(40.0)
	lows.push(60.0)
	_check(is_equal_approx(lows.one_percent_low(), 20.0), "1% low worst two frames")
	print("FrameGauge tests: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)

func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
