extends SceneTree
const FGMetrics = preload("res://addons/pft_benchmark/metric_config.gd")

func _initialize() -> void:
	var seen := {}
	for group in FGMetrics.GROUPS:
		for id in FGMetrics.GROUPS[group]:
			assert(FGMetrics.METRICS.has(id))
			assert(not seen.has(id))
			seen[id] = true
	assert(seen.size() == 24)
	assert(FGMetrics.visible_in_mode("fps", 0))
	assert(not FGMetrics.visible_in_mode("graph", 0))
	assert(FGMetrics.visible_in_mode("graph", 1))
	assert(not FGMetrics.visible_in_mode("pairs", 1))
	assert(FGMetrics.visible_in_mode("pairs", 2))
	assert(FGMetrics.visible_in_mode("pairs", 3))
	ProjectSettings.set_setting("pft_benchmark/show_graph", false)
	assert(not FGMetrics.default_enabled("graph"))
	ProjectSettings.set_setting("pft_benchmark/metric_graph", true)
	assert(FGMetrics.selected("graph"))
	ProjectSettings.set_setting("pft_benchmark/metric_graph", false)
	assert(not FGMetrics.selected("graph"))
	print("Metric schema OK")
	quit()
