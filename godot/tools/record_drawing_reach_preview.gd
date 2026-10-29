extends Control

const Evaluator := preload("res://scripts/drawing_reach_evaluator.gd")
const DrawingSurface := preload("res://scripts/drawing_surface.gd")
const LocalVideoRecorder := preload("res://scripts/local_video_recorder.gd")

const SAVE_PATH := "user://albia_norn_save.json"
const OUTPUT_DIRECTORY := "C:/Users/Quad/Documents/Codex/2026-10-29/audit-review-and-verify-this-report-2/outputs/single-point-reach-preview"
const USER_RECORDINGS_DIRECTORY := "user://recordings"
const DECISION_INTERVAL_SECONDS := 0.2
const BOARD_RECT := Rect2(Vector2(400.0, 145.0), Vector2(480.0, 480.0))

var _trial: Dictionary = {}
var _surface: RefCounted
var _recorder: LocalVideoRecorder
var _title_label: Label
var _details_label: Label
var _score_label: Label
var _previous_save_exists := false
var _previous_save_bytes := PackedByteArray()
var _save_backup_ready := false
var _save_restored := false
var _recordings_before := -1


func _ready() -> void:
	_build_display()
	if not _backup_user_save():
		_fail("The existing local save could not be backed up.")
		return
	_recordings_before = _user_recording_count()
	if _recordings_before > LocalVideoRecorder.MAX_SAVED_CLIPS:
		_fail("The user recordings folder is already over the 10-clip limit; no existing clips were removed.")
		return
	_trial = Evaluator.create_trial(9901, 0)
	if _trial.is_empty():
		_fail("The temporary single-point reach trial could not be created.")
		return
	_surface = _trial["surface"]
	_recorder = LocalVideoRecorder.new()
	_recorder.name = "ReachPreviewRecorder"
	_recorder.recordings_directory = OUTPUT_DIRECTORY
	add_child(_recorder)
	_update_labels()
	queue_redraw()
	call_deferred("_run_capture")


func _draw() -> void:
	var background := Rect2(Vector2.ZERO, get_viewport_rect().size)
	draw_rect(background, Color("#202932"), true)
	draw_rect(BOARD_RECT.grow(12.0), Color("#3b4650"), true)
	if _surface == null or _surface.texture == null:
		return
	draw_texture_rect(_surface.texture, BOARD_RECT, false)
	var start_uv := Vector2(128.0 / 255.0, 128.0 / 255.0)
	var start_position := _uv_to_screen(start_uv)
	var target_position := _uv_to_screen(_trial.get("targetUv", Vector2(0.74, 0.5)))
	var cursor_position := _uv_to_screen(_surface.get_last_uv(Evaluator.ACTOR_ID))
	draw_circle(start_position, 7.0, Color("#42d392"))
	draw_arc(target_position, 15.0, 0.0, TAU, 48, Color("#ff5b5b"), 3.0, true)
	draw_line(target_position + Vector2(-22.0, 0.0), target_position + Vector2(22.0, 0.0), Color("#ff5b5b"), 2.0, true)
	draw_line(target_position + Vector2(0.0, -22.0), target_position + Vector2(0.0, 22.0), Color("#ff5b5b"), 2.0, true)
	draw_circle(cursor_position, 6.0, Color("#ffc857"))


func _build_display() -> void:
	_title_label = _make_label("Single-point reach | isolated no-update trial", Vector2(72.0, 36.0), Vector2(1136.0, 44.0), 30, Color("#f1f4f6"))
	_details_label = _make_label("", Vector2(72.0, 84.0), Vector2(1136.0, 32.0), 18, Color("#cad3db"))
	_score_label = _make_label("", Vector2(72.0, 648.0), Vector2(1136.0, 34.0), 20, Color("#f1f4f6"))


func _make_label(text: String, position: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _uv_to_screen(uv: Vector2) -> Vector2:
	return BOARD_RECT.position + Vector2(uv.x * BOARD_RECT.size.x, uv.y * BOARD_RECT.size.y)


func _update_labels() -> void:
	var step_count := int(_trial.get("stepCount", 0))
	var direction_index := int(_trial.get("directionIndex", 0))
	_details_label.text = "Seed 9901 | target direction %d | %d / 6 decisions | %.1f simulated seconds" % [
		direction_index,
		step_count,
		float(_trial.get("simulatedSeconds", 0.0))
	]
	if bool(_trial.get("complete", false)) and not bool(_trial.get("failed", false)):
		_score_label.text = "Endpoint error: %.2f pixels | Hit within 8 pixels: %s" % [
			float(_trial["errorPixels"]),
			"yes" if bool(_trial["hit"]) else "no"
		]
	else:
		_score_label.text = "Green = quantized start | Red = target | Gold = current quantized cursor"


func _run_capture() -> void:
	for _frame_index: int in range(8):
		await get_tree().process_frame
	if _recorder.start_recording() != OK:
		_fail("Could not start the rendered target-reach capture: %s" % _recorder.last_error)
		return
	await get_tree().create_timer(0.35).timeout
	for step_index: int in range(Evaluator.DECISIONS_PER_TRIAL):
		await get_tree().create_timer(DECISION_INTERVAL_SECONDS).timeout
		var complete := Evaluator.advance_trial(_trial)
		if bool(_trial.get("failed", false)):
			_fail(str(_trial.get("failureReason", "The reach trial failed.")))
			return
		_update_labels()
		queue_redraw()
		await get_tree().process_frame
		if complete != (step_index == Evaluator.DECISIONS_PER_TRIAL - 1):
			_fail("The rendered reach trial did not finish on exactly the sixth decision.")
			return
	await get_tree().create_timer(0.55).timeout
	if _recorder.is_recording():
		var stop_error: Error = _recorder.stop_recording()
		if stop_error != OK:
			_fail("Could not finalize the rendered reach capture: %s" % _recorder.last_error)
			return
	if _recorder.is_recording() or _recorder.last_recording_path.is_empty() or _recorder.recorded_frame_count < 20:
		_fail("The rendered reach capture did not finalize with at least 20 frames.")
		return
	_restore_user_save()
	if not _user_save_matches_backup():
		_fail("The local save did not return to its original bytes and existence state.")
		return
	var recordings_after := _user_recording_count()
	if recordings_after != _recordings_before or recordings_after > LocalVideoRecorder.MAX_SAVED_CLIPS:
		_fail("The user recordings count changed or exceeds the 10-clip limit.")
		return
	print("DRAWING_REACH_PREVIEW_OK path=%s frames=%d error_pixels=%.6f hit=%s user_recordings=%d save_restored=true" % [
		_recorder.last_recording_path,
		_recorder.recorded_frame_count,
		float(_trial["errorPixels"]),
		str(bool(_trial["hit"])),
		recordings_after
	])
	get_tree().quit()


func _backup_user_save() -> bool:
	_previous_save_exists = FileAccess.file_exists(SAVE_PATH)
	if _previous_save_exists:
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file == null:
			return false
		_previous_save_bytes = file.get_buffer(file.get_length())
		file.close()
	_save_backup_ready = true
	return true


func _restore_user_save() -> bool:
	if not _save_backup_ready:
		return false
	if _previous_save_exists:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file == null:
			return false
		file.store_buffer(_previous_save_bytes)
		file.close()
	else:
		var absolute_path := ProjectSettings.globalize_path(SAVE_PATH)
		if FileAccess.file_exists(SAVE_PATH):
			var remove_error := DirAccess.remove_absolute(absolute_path)
			if remove_error != OK:
				return false
	_save_restored = true
	return true


func _user_save_matches_backup() -> bool:
	if FileAccess.file_exists(SAVE_PATH) != _previous_save_exists:
		return false
	if not _previous_save_exists:
		return true
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var current_bytes := file.get_buffer(file.get_length())
	file.close()
	return current_bytes == _previous_save_bytes


func _user_recording_count() -> int:
	var absolute_directory := ProjectSettings.globalize_path(USER_RECORDINGS_DIRECTORY)
	var directory := DirAccess.open(absolute_directory)
	if directory == null:
		return 0
	var count := 0
	for file_name: String in directory.get_files():
		if file_name.get_extension().to_lower() == "avi":
			count += 1
	return count


func _fail(message: String) -> void:
	if _recorder != null and _recorder.is_recording():
		_recorder.stop_recording()
	_restore_user_save()
	push_error("DRAWING_REACH_PREVIEW_FAILED: " + message)
	get_tree().quit(1)


func _exit_tree() -> void:
	if _recorder != null and _recorder.is_recording():
		_recorder.stop_recording()
	if not _save_restored:
		_restore_user_save()
