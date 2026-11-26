extends RefCounted
## Slow, best-effort host counters. No shell commands, native modules or network.
var _cpu_total_previous: int = -1
var _cpu_idle_previous: int = -1
var _gpu_path := ""
var _gpu_scanned := false

func sample(want_ram: bool = true, want_cpu: bool = true, want_gpu: bool = true) -> Dictionary:
	var mem := OS.get_memory_info() if want_ram else {}
	var result := {"ram_total": int(mem.get("physical", -1)), "ram_free": int(mem.get("free", -1)), "cpu": -1.0, "gpu": -1.0}
	if OS.get_name() != "Linux":
		return result
	var stat := FileAccess.open("/proc/stat", FileAccess.READ) if want_cpu else null
	if stat != null:
		var line := stat.get_line().replace("\t", " ").split(" ", false)
		if line.size() >= 9 and line[0] == "cpu":
			var total: int = 0
			for i in range(1, 9):
				total += int(line[i])
			var idle := int(line[4]) + int(line[5])
			result["cpu"] = cpu_busy_percent(_cpu_total_previous, _cpu_idle_previous, total, idle)
			_cpu_total_previous = total
			_cpu_idle_previous = idle
	else:
		_cpu_total_previous = -1
		_cpu_idle_previous = -1
	if want_gpu and not _gpu_scanned:
		_gpu_scanned = true
		var paths: Array[String] = []
		var dir := DirAccess.open("/sys/class/drm")
		if dir != null:
			dir.list_dir_begin()
			var entry := dir.get_next()
			while not entry.is_empty():
				if entry.begins_with("card") and entry.substr(4).is_valid_int():
					var path := "/sys/class/drm/" + entry + "/device/gpu_busy_percent"
					if FileAccess.file_exists(path):
						paths.append(path)
				entry = dir.get_next()
			dir.list_dir_end()
		# Only one readable busy counter; this is host GPU activity, not per-game.
		if paths.size() == 1:
			_gpu_path = paths[0]
	if want_gpu and not _gpu_path.is_empty():
		var gpu := FileAccess.open(_gpu_path, FileAccess.READ)
		if gpu != null:
			var value := gpu.get_line().strip_edges()
			if value.is_valid_float() and float(value) >= 0.0 and float(value) <= 100.0:
				result["gpu"] = float(value)
	return result

## Host-wide Linux CPU activity; unavailable for first sample or reset counters.
static func cpu_busy_percent(previous_total: int, previous_idle: int, total: int, idle: int) -> float:
	if previous_total < 0 or previous_idle < 0 or total <= previous_total or idle < previous_idle:
		return -1.0
	var elapsed := total - previous_total
	var idle_elapsed := idle - previous_idle
	if idle_elapsed > elapsed:
		return -1.0
	return 100.0 * (1.0 - float(idle_elapsed) / float(elapsed))
