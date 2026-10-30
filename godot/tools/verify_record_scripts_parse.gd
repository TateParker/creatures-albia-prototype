extends SceneTree

const RECORD_SCRIPT_PATHS: Array[String] = [
	"res://tools/record_preview.gd",
	"res://tools/record_drawing_preview.gd",
	"res://tools/record_drawing_reach_preview.gd",
	"res://tools/record_expanded_habitat_preview.gd"
]


func _initialize() -> void:
	for script_path: String in RECORD_SCRIPT_PATHS:
		if load(script_path) == null:
			push_error("RECORD_SCRIPT_PARSE_FAILED: " + script_path)
			quit(1)
			return
	print("RECORD_SCRIPT_PARSE_OK count=%d" % RECORD_SCRIPT_PATHS.size())
	quit()
