@tool
extends EditorDebuggerPlugin

signal sample_received(session_id: int, sample: Dictionary)

func _has_capture(capture: String) -> bool:
	return capture == "pft_benchmark"

func _capture(message: String, data: Array, session_id: int) -> bool:
	if message != "pft_benchmark:sample":
		return false
	if data.size() == 1 and data[0] is Dictionary:
		sample_received.emit(session_id, data[0])
	return true
