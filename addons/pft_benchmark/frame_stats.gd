extends RefCounted
## Fixed-capacity ring of real elapsed frame intervals in milliseconds.

var _data := PackedFloat64Array()
var _next := 0
var count := 0
var capacity := 600
var _sum := 0.0

func _init(max_frames: int = 600) -> void:
	capacity = clampi(max_frames, 1, 1200)
	_data.resize(capacity)

func clear() -> void:
	_next = 0
	count = 0
	_sum = 0.0

func push(ms: float) -> void:
	if not is_finite(ms) or ms <= 0.0:
		return
	if count == capacity:
		_sum -= _data[_next]
	else:
		count += 1
	_data[_next] = ms
	_sum += ms
	_next = (_next + 1) % capacity

func latest() -> float:
	return _data[posmod(_next - 1, capacity)] if count > 0 else 0.0

func average_fps() -> float:
	return 1000.0 * count / _sum if count > 0 and _sum > 0.0 else 0.0

func samples(limit: int = 1200) -> PackedFloat64Array:
	var n := clampi(limit, 0, count)
	var result := PackedFloat64Array()
	result.resize(n)
	for i in range(n):
		result[i] = _data[posmod(_next - n + i, capacity)]
	return result

func one_percent_low() -> float:
	# Require 100 frames: otherwise the worst 1% is not meaningful.
	if count < 100:
		return 0.0
	var sorted := samples()
	sorted.sort()
	var n := maxi(1, ceili(float(count) * 0.01))
	var tail_sum := 0.0
	for i in range(count - n, count):
		tail_sum += sorted[i]
	return 1000.0 * n / tail_sum if tail_sum > 0.0 else 0.0
