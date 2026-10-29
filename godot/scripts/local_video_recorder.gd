class_name LocalVideoRecorder
extends Node

const AviWriter = preload("res://scripts/mjpeg_avi_writer.gd")
const RECORDINGS_DIRECTORY := "user://recordings"
const MAX_SAVED_CLIPS := 10
const CAPTURE_SIZE := Vector2i(1280, 720)
const CAPTURE_FPS := 15
const FRAME_INTERVAL := 1.0 / float(CAPTURE_FPS)
const JPEG_QUALITY := 0.75

var recording_active: bool = false
var recording_elapsed: float = 0.0
var recorded_frame_count: int = 0
var recordings_directory: String = RECORDINGS_DIRECTORY
var current_recording_path: String = ""
var last_recording_path: String = ""
var last_error: String = ""
var last_pruned_clip_count: int = 0

var _writer: MjpegAviWriter
var _capture_accumulator: float = 0.0
var _capture_pending: bool = false
var _last_recording_duration: float = 0.0


func _process(delta: float) -> void:
	if not recording_active:
		return
	recording_elapsed += maxf(0.0, delta)
	_capture_accumulator += maxf(0.0, delta)
	if _capture_pending or _capture_accumulator < FRAME_INTERVAL:
		return
	_capture_accumulator = fmod(_capture_accumulator, FRAME_INTERVAL)
	_capture_pending = true
	_capture_frame_after_draw()


func start_recording() -> Error:
	if recording_active:
		return ERR_ALREADY_IN_USE
	var recordings_path := ProjectSettings.globalize_path(recordings_directory)
	var directory_error := DirAccess.make_dir_recursive_absolute(recordings_path)
	if directory_error != OK and not DirAccess.dir_exists_absolute(recordings_path):
		last_error = "Could not create the local recordings folder (error %d)." % directory_error
		return directory_error
	var file_path := _unique_recording_path()
	var writer := AviWriter.new()
	var writer_error: Error = writer.begin(ProjectSettings.globalize_path(file_path), CAPTURE_SIZE, CAPTURE_FPS)
	if writer_error != OK:
		last_error = "Could not create the video file (error %d)." % writer_error
		return writer_error
	_writer = writer
	current_recording_path = file_path
	last_recording_path = ""
	last_error = ""
	recorded_frame_count = 0
	recording_elapsed = 0.0
	_capture_accumulator = 0.0
	last_pruned_clip_count = 0
	recording_active = true
	return OK


func stop_recording() -> Error:
	if not recording_active or _writer == null:
		return ERR_UNCONFIGURED
	recording_active = false
	_capture_accumulator = 0.0
	_last_recording_duration = recording_elapsed
	var frame_count := _writer.frame_count()
	var finish_error: Error = _writer.finish()
	_writer = null
	recorded_frame_count = frame_count
	if finish_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(current_recording_path))
		last_error = "The recording ended before a video frame could be saved."
		current_recording_path = ""
		return finish_error
	last_recording_path = current_recording_path
	current_recording_path = ""
	var prune_error: Error = prune_recordings()
	if prune_error != OK:
		last_error = "Saved the clip, but could not enforce the %d clip limit (error %d)." % [MAX_SAVED_CLIPS, prune_error]
	return OK


func is_recording() -> bool:
	return recording_active


func recording_time() -> float:
	return recording_elapsed if recording_active else _last_recording_duration


func open_recordings_folder() -> Error:
	var recordings_path := ProjectSettings.globalize_path(recordings_directory)
	var directory_error := DirAccess.make_dir_recursive_absolute(recordings_path)
	if directory_error != OK and not DirAccess.dir_exists_absolute(recordings_path):
		last_error = "Could not open the local recordings folder (error %d)." % directory_error
		return directory_error
	var open_error := OS.shell_open(recordings_path)
	if open_error != OK:
		last_error = "Could not open the local recordings folder (error %d)." % open_error
	return open_error


func prune_recordings() -> Error:
	var absolute_directory := ProjectSettings.globalize_path(recordings_directory)
	var directory := DirAccess.open(absolute_directory)
	if directory == null:
		last_error = "Could not scan the local recordings folder (error %d)." % DirAccess.get_open_error()
		return DirAccess.get_open_error()
	var clips: PackedStringArray = []
	for file_name in directory.get_files():
		if file_name.get_extension().to_lower() == "avi":
			clips.append(file_name)
	clips.sort()
	last_pruned_clip_count = 0
	var excess_count := clips.size() - MAX_SAVED_CLIPS
	for index in range(maxi(0, excess_count)):
		var old_clip_path := absolute_directory.path_join(clips[index])
		var remove_error := DirAccess.remove_absolute(old_clip_path)
		if remove_error != OK:
			last_error = "Could not remove an old clip to enforce the %d clip limit (error %d)." % [MAX_SAVED_CLIPS, remove_error]
			return remove_error
		last_pruned_clip_count += 1
	return OK


func _capture_frame_after_draw() -> void:
	await RenderingServer.frame_post_draw
	_capture_pending = false
	if not recording_active or _writer == null:
		return
	var viewport := get_viewport()
	if viewport == null:
		_stop_after_capture_error("The game viewport is no longer available.")
		return
	var image: Image = viewport.get_texture().get_image()
	if image.is_empty():
		_stop_after_capture_error("The game viewport returned an empty frame.")
		return
	if image.get_size() != CAPTURE_SIZE:
		image.resize(CAPTURE_SIZE.x, CAPTURE_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var jpg_bytes := image.save_jpg_to_buffer(JPEG_QUALITY)
	if jpg_bytes.is_empty():
		_stop_after_capture_error("Godot could not encode the viewport frame as JPEG.")
		return
	var write_error: Error = _writer.write_frame(jpg_bytes)
	if write_error != OK:
		if write_error == ERR_OUT_OF_MEMORY:
			last_error = "Recording stopped before reaching the AVI 4 GiB size limit."
		else:
			last_error = "Could not write a video frame (error %d)." % write_error
		_finish_after_capture_error()
		return
	recorded_frame_count = _writer.frame_count()


func _stop_after_capture_error(message: String) -> void:
	last_error = message
	_finish_after_capture_error()


func _finish_after_capture_error() -> void:
	if _writer == null:
		recording_active = false
		return
	_last_recording_duration = recording_elapsed
	var finish_error: Error = _writer.finish()
	recorded_frame_count = _writer.frame_count()
	_writer = null
	recording_active = false
	_capture_accumulator = 0.0
	if finish_error == OK:
		last_recording_path = current_recording_path
		current_recording_path = ""
		var prune_error: Error = prune_recordings()
		if prune_error != OK:
			last_error = "Saved the clip, but could not enforce the %d clip limit (error %d)." % [MAX_SAVED_CLIPS, prune_error]
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(current_recording_path))
		current_recording_path = ""


func _timestamp() -> String:
	var now := Time.get_datetime_dict_from_system()
	return "%04d%02d%02d-%02d%02d%02d" % [
		int(now["year"]), int(now["month"]), int(now["day"]),
		int(now["hour"]), int(now["minute"]), int(now["second"])
	]


func _unique_recording_path() -> String:
	var base_name := "habitat-%s" % _timestamp()
	var file_path := recordings_directory.path_join(base_name + ".avi")
	var suffix := 1
	while FileAccess.file_exists(ProjectSettings.globalize_path(file_path)):
		file_path = recordings_directory.path_join("%s-%02d.avi" % [base_name, suffix])
		suffix += 1
	return file_path


func _exit_tree() -> void:
	if recording_active and _writer != null:
		_finish_after_capture_error()
