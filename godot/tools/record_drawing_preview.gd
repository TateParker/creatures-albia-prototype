extends SceneTree

const HabitatScene = preload("res://scenes/main.tscn")
const SAVE_PATH := "user://albia_norn_save.json"
const OUTPUT_DIRECTORY := "C:/Users/Quad/Documents/Codex/2026-10-29/audit-review-and-verify-this-report-2/outputs/drawing-preview-recordings"

var _world: Node
var _previous_save_exists := false
var _previous_save_text := ""
var _save_backup_ready := false
var _save_restored := false
var _saw_draw_decision := false
var _saw_approach := false
var _saw_contact := false


func _initialize() -> void:
	call_deferred("_record_drawing_preview")


func _record_drawing_preview() -> void:
	if not _backup_user_save():
		_fail("The existing local save could not be backed up safely.")
		return
	var existing_user_recordings := _user_recording_count()
	print("USER_RECORDINGS_PATH=%s count_before=%d" % [ProjectSettings.globalize_path("user://recordings"), existing_user_recordings])
	if existing_user_recordings > 10:
		_fail("The existing user recordings folder is already over the 10-clip cap; no existing clips were removed.")
		return
	_world = HabitatScene.instantiate()
	root.add_child(_world)
	await process_frame
	if _world == null or not _world.has_method("_run_decision"):
		_fail("The habitat or decision loop could not be created.")
		return
	_world.set_process(false)
	_world.set("paused", false)
	_world.set("simulation_speed", 1.0)
	var recorder: Object = _world.get("video_recorder")
	if recorder == null:
		_fail("The local video recorder is unavailable.")
		return
	recorder.set("recordings_directory", OUTPUT_DIRECTORY)
	var profile: Variant = _world.call("profile_for", "mallow")
	var moss_profile: Variant = _world.call("profile_for", "moss")
	if profile == null or profile.get("actor") == null:
		_fail("Mallow could not be found for the mark-making walkthrough.")
		return
	var chemistry: Dictionary = profile.get("cognition_state")["chemistry"]
	chemistry["hunger"] = 5.0
	chemistry["glucose"] = 95.0
	chemistry["curiosity"] = 100.0
	chemistry["fatigue"] = 5.0
	profile.get("cognition_state")["actionAssociations"]["draw"] = 1.0
	if moss_profile != null and moss_profile.get("actor") != null:
		moss_profile.get("actor").set_physics_process(false)
	(_world.get("objects") as Dictionary)["spinner"].set_available(false)
	_world.call("_refresh_ui")
	for frame in range(8):
		await process_frame
	_world.call("toggle_recording")
	if not bool(_world.call("is_recording")):
		_fail("The drawing walkthrough recording did not start.")
		return
	var drawing_surface: Variant = _world.get("drawing_surface")
	var surface_item: Node3D = (_world.get("objects") as Dictionary)["drawing_surface"] as Node3D
	var walking_actor: NornActor = profile.get("actor") as NornActor
	for decision_step in range(72):
		_world.set("simulation_time", float(_world.get("simulation_time")) + 0.2)
		_world.call("_run_decision", profile)
		_world.call("_refresh_ui")
		var current_decision: Dictionary = profile.get("current_decision")
		var drawing_selected := str(current_decision.get("actionId", "")) == "draw"
		var near_surface: bool = walking_actor.global_position.distance_to(surface_item.global_position) <= 1.05
		_saw_draw_decision = _saw_draw_decision or drawing_selected
		_saw_approach = _saw_approach or (drawing_selected and not near_surface)
		_saw_contact = _saw_contact or (drawing_selected and near_surface and drawing_surface.call("get_stroke_count") > 0)
		for frame in range(12):
			await process_frame
		near_surface = walking_actor.global_position.distance_to(surface_item.global_position) <= 1.05
		_saw_contact = _saw_contact or (drawing_selected and near_surface and drawing_surface.call("get_stroke_count") > 0)
	if not _saw_draw_decision or not _saw_approach or not _saw_contact or drawing_surface.call("get_stroke_count") < 1:
		_fail("Mallow did not approach and leave an incremental mark on the board.")
		return
	var surface_record: Dictionary = drawing_surface.call("serialize_state")
	var surface_marks: PackedFloat32Array = drawing_surface.call("sample_mark_grid", drawing_surface.call("get_last_uv", "mallow"), 16)
	if _sum(surface_marks) <= 0.0:
		_fail("The board texture did not produce a changed local perception grid.")
		return
	_world.call("toggle_pause")
	_world.call("save_game")
	var saved_record := _read_save()
	if saved_record.is_empty() or saved_record.get("version", -1) != 6:
		_fail("The rendered walkthrough did not write a version-6 save.")
		return
	if not _deep_values_match(saved_record.get("drawingSurface", {}), surface_record):
		_fail("The version-6 save omitted or changed the visible board data.")
		return
	for frame in range(12):
		await process_frame
	var blank_record := {"version": 1, "strokes": [], "cursors": []}
	if not bool(drawing_surface.call("restore_state", blank_record)):
		_fail("The temporary board-clear step failed.")
		return
	_world.call("_refresh_ui")
	for frame in range(12):
		await process_frame
	_world.call("load_game")
	profile = _world.call("profile_for", "mallow")
	drawing_surface = _world.get("drawing_surface")
	if not _deep_values_match(drawing_surface.call("serialize_state"), surface_record):
		_fail("Loading the saved world did not restore the board and cursor.")
		return
	for frame in range(30):
		await process_frame
	var texture_id: int = drawing_surface.get("texture").get_instance_id()
	_world.call("_reset_state", false)
	drawing_surface = _world.get("drawing_surface")
	if drawing_surface.call("get_stroke_count") != 0 or drawing_surface.get("texture").get_instance_id() != texture_id:
		_fail("Reset did not clear the board while keeping its rendered texture connected.")
		return
	_world.call("_refresh_ui")
	for frame in range(12):
		await process_frame
	_world.call("load_game")
	profile = _world.call("profile_for", "mallow")
	drawing_surface = _world.get("drawing_surface")
	if not _deep_values_match(drawing_surface.call("serialize_state"), surface_record):
		_fail("Reload after reset did not restore the saved board and cursor.")
		return
	for frame in range(18):
		await process_frame
	(_world.get("objects") as Dictionary)["spinner"].set_available(true)
	profile.get("cognition_state")["actionAssociations"]["draw"] = 0.5
	_world.call("toggle_pause")
	_world.set_process(true)
	for frame in range(75):
		await process_frame
	_world.call("toggle_recording")
	await process_frame
	if bool(_world.call("is_recording")):
		_fail("The drawing walkthrough recording did not finalize.")
		return
	var video_path := str(_world.get("last_recording_path"))
	var frame_count := int(_world.get("recorded_frame_count"))
	if frame_count < 80 or video_path.is_empty() or not FileAccess.file_exists(video_path):
		_fail("The drawing walkthrough did not create a complete AVI capture.")
		return
	var folder_clips := _user_recording_count()
	if folder_clips > 10:
		_fail("The pre-existing user recordings folder contains more than 10 finalized clips.")
		return
	_restore_user_save()
	print("DRAWING_PREVIEW_OK frames=%d strokes=%d path=%s user_recordings=%d selected=%s approach=%s contact=%s save_load=true reset_clear=true normal_habitat=true" % [
		frame_count,
		surface_record.get("strokes", []).size(),
		video_path,
		folder_clips,
		_saw_draw_decision,
		_saw_approach,
		_saw_contact
	])
	quit()


func _backup_user_save() -> bool:
	_previous_save_exists = FileAccess.file_exists(SAVE_PATH)
	if _previous_save_exists:
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file == null:
			return false
		_previous_save_text = file.get_as_text()
		file.close()
	_save_backup_ready = true
	return true


func _restore_user_save() -> void:
	if not _save_backup_ready or _save_restored:
		return
	if _previous_save_exists:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(_previous_save_text)
			file.close()
	else:
		var absolute_path := ProjectSettings.globalize_path(SAVE_PATH)
		if FileAccess.file_exists(SAVE_PATH):
			DirAccess.remove_absolute(absolute_path)
	_save_restored = true


func _read_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _user_recording_count() -> int:
	var folder := ProjectSettings.globalize_path("user://recordings")
	var directory := DirAccess.open(folder)
	if directory == null:
		print("USER_RECORDINGS_FOLDER_MISSING=true")
		return 0
	var count := 0
	for file_name: String in directory.get_files():
		if file_name.get_extension().to_lower() == "avi":
			count += 1
	return count


func _sum(values: PackedFloat32Array) -> float:
	var total := 0.0
	for value: float in values:
		total += value
	return total


func _deep_values_match(actual: Variant, expected: Variant) -> bool:
	if (actual is int or actual is float) and (expected is int or expected is float):
		return is_equal_approx(float(actual), float(expected))
	if actual is Dictionary and expected is Dictionary:
		if actual.size() != expected.size():
			return false
		for key: Variant in expected:
			if not actual.has(key) or not _deep_values_match(actual[key], expected[key]):
				return false
		return true
	if actual is Array and expected is Array:
		if actual.size() != expected.size():
			return false
		for index: int in range(expected.size()):
			if not _deep_values_match(actual[index], expected[index]):
				return false
		return true
	return actual == expected


func _fail(message: String) -> void:
	if _world != null and _world.has_method("is_recording") and bool(_world.call("is_recording")):
		_world.call("toggle_recording")
	_restore_user_save()
	push_error("DRAWING_PREVIEW_FAILED: " + message)
	quit(1)


func _exit_tree() -> void:
	_restore_user_save()
