@tool
extends RefCounted

const PREFIX := "pft_benchmark/"
const GROUPS := {
	"FRAME STATISTICS": ["fps", "frame", "average", "low", "graph"],
	"MEMORY & HARDWARE": ["memory", "vram", "host_ram", "host_cpu", "host_gpu"],
	"RENDERING": ["calls", "primitives", "nodes", "objects"],
	"TIMING": ["process_time", "physics_time", "cpu_render", "gpu_render"],
	"ADVANCED": ["range", "spikes", "active", "pairs", "self_cost", "hardware"],
}
const METRICS := {
	"fps": ["FPS", "", 0],
	"frame": ["Frame time", "", 0],
	"average": ["Average FPS", "", 1],
	"low": ["1% Low", "", 1],
	"graph": ["Graph", "show_graph", 1],
	"memory": ["Engine memory", "show_memory", 1],
	"vram": ["Video memory", "show_memory", 1],
	"host_ram": ["Host free / total RAM", "show_system", 1],
	"host_cpu": ["Host CPU busy", "show_system", 1],
	"host_gpu": ["DRM GPU busy", "show_system", 1],
	"calls": ["Draw calls", "show_render", 1],
	"primitives": ["Render primitives", "show_render", 1],
	"nodes": ["Nodes", "show_render", 1],
	"objects": ["Render objects", "show_render", 1],
	"process_time": ["Process time", "", 1],
	"physics_time": ["Physics time", "show_physics", 1],
	"cpu_render": ["Render CPU time", "", 1],
	"gpu_render": ["Render GPU time", "", 1],
	"range": ["Min / max FPS", "", 2],
	"spikes": ["Frames > 33 ms", "", 2],
	"active": ["Active bodies 2D/3D", "show_physics", 2],
	"pairs": ["Collision pairs 2D/3D", "show_physics", 2],
	"self_cost": ["HUD update CPU time", "", 2],
	"hardware": ["System information", "", 2],
}

static func default_enabled(id: String) -> bool:
	var legacy: String = METRICS[id][1]
	return legacy.is_empty() or bool(ProjectSettings.get_setting(PREFIX + legacy, true))

static func selected(id: String) -> bool:
	return bool(ProjectSettings.get_setting(PREFIX + "metric_" + id, default_enabled(id)))

static func visible_in_mode(id: String, mode: int) -> bool:
	return mode == 3 or mode >= int(METRICS[id][2])
