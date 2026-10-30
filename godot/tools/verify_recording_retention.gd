extends SceneTree

const RecorderScript = preload("res://scripts/local_video_recorder.gd")
const TEST_CLIP_COUNT := 11
const MAX_EXPECTED_CLIPS := 10

var _test_directory := ""
var _review_directory := ""


func _initialize() -> void:
	call_deferred("_verify_retention")


func _verify_retention() -> void:
	_test_directory = OS.get_user_data_dir().path_join("recording-retention-check-%d" % Time.get_ticks_msec())
	var directory_error := DirAccess.make_dir_recursive_absolute(_test_directory)
	if directory_error != OK:
		_fail("Could not create the temporary recordings folder (error %d)." % directory_error)
		return
	_review_directory = _test_directory.path_join("expanded-habitat-review")
	if DirAccess.make_dir_recursive_absolute(_review_directory) != OK:
		_fail("Could not create the nested temporary recordings folder.")
		return
	var recorder: LocalVideoRecorder = RecorderScript.new()
	root.add_child(recorder)
	if not recorder.has_method("prune_recordings"):
		_fail("Local recording retention is not implemented yet.")
		return
	if not _has_recordings_directory_property(recorder):
		_fail("The recorder cannot target an isolated output folder for verification.")
		return
	if _has_property(recorder, "recordings_root"):
		recorder.set("recordings_root", _test_directory)
	recorder.set("recordings_directory", _review_directory)

	for clip_index in range(TEST_CLIP_COUNT):
		var clip_name := "habitat-20250101-0000%02d.avi" % clip_index
		var clip_directory := _test_directory if clip_index < 6 else _review_directory
		var clip := FileAccess.open(clip_directory.path_join(clip_name), FileAccess.WRITE)
		if clip == null:
			_fail("Could not create temporary clip %s." % clip_name)
			return
		clip.store_string("temporary clip %02d" % clip_index)
		clip.close()

	var start_error: Error = recorder.start_recording()
	if start_error != OK:
		_fail("The recorder could not start in the isolated test folder (error %d)." % start_error)
		return
	var writer: Object = recorder.get("_writer")
	var frame := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	frame.fill(Color(0.2, 0.65, 0.35))
	var write_error: Error = writer.call("write_frame", frame.save_jpg_to_buffer(0.75))
	if write_error != OK:
		_fail("The test frame could not be written (error %d)." % write_error)
		return
	var saved_path := recorder.current_recording_path
	var prune_while_active: Error = recorder.prune_recordings()
	if prune_while_active != OK or not FileAccess.file_exists(saved_path):
		_fail("Pruning while a recording is active removes or damages the current clip.")
		return
	var stop_error: Error = recorder.stop_recording()
	if stop_error != OK:
		_fail("The new test clip could not be finalized (error %d)." % stop_error)
		return
	var remaining := _find_clips(_test_directory)
	if remaining.size() != MAX_EXPECTED_CLIPS:
		_fail("Expected %d retained clips across nested folders; found %d." % [MAX_EXPECTED_CLIPS, remaining.size()])
		return
	if _has_clip_named(remaining, "habitat-20250101-000000.avi") or _has_clip_named(remaining, "habitat-20250101-000001.avi"):
		_fail("The oldest clips were not replaced after the new clip was saved.")
		return
	if not _has_clip_named(remaining, "habitat-20250101-000002.avi") or not FileAccess.file_exists(saved_path):
		_fail("The newest old clip or newly saved clip was not retained.")
		return

	_cleanup()
	print("VIDEO_RETENTION_OK limit=%d removed=2 new_clip_kept=true" % MAX_EXPECTED_CLIPS)
	quit()


func _has_recordings_directory_property(recorder: Object) -> bool:
	return _has_property(recorder, "recordings_directory")


func _has_property(target: Object, property_name: String) -> bool:
	for property: Dictionary in target.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false


func _find_clips(directory_path: String) -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return result
	for file_name: String in directory.get_files():
		if file_name.get_extension().to_lower() == "avi":
			result.append(directory_path.path_join(file_name))
	for child_directory: String in directory.get_directories():
		result.append_array(_find_clips(directory_path.path_join(child_directory)))
	return result


func _has_clip_named(paths: Array[String], file_name: String) -> bool:
	for path: String in paths:
		if path.get_file() == file_name:
			return true
	return false


func _cleanup() -> void:
	_remove_tree(_test_directory)


func _remove_tree(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)
	if directory != null:
		for file_name: String in directory.get_files():
			DirAccess.remove_absolute(directory_path.path_join(file_name))
		for child_directory: String in directory.get_directories():
			_remove_tree(directory_path.path_join(child_directory))
	DirAccess.remove_absolute(directory_path)


func _fail(message: String) -> void:
	_cleanup()
	push_error("VIDEO_RETENTION_FAILED: " + message)
	quit(1)
