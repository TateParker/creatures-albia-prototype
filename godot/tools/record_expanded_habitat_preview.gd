extends SceneTree

const HabitatScene = preload("res://scenes/main.tscn")
const Biochemistry = preload("res://scripts/norn_biochemistry.gd")
const Cognition = preload("res://scripts/norn_cognition.gd")
const SAVE_PATH := "user://albia_norn_save.json"
const REVIEW_RECORDINGS_DIRECTORY := "user://recordings/expanded-habitat-review"

var _world: Node
var _previous_save_exists := false
var _previous_save_text := ""
var _save_backup_ready := false
var _recording_started := false


func _initialize() -> void:
	call_deferred("_record_expanded_habitat")


func _record_expanded_habitat() -> void:
	if not _backup_user_save():
		_fail("The existing local save could not be backed up safely.")
		return
	_world = HabitatScene.instantiate()
	root.add_child(_world)
	await process_frame
	if _world == null or not _world.has_method("guide_to") or not _world.has_method("is_recording"):
		_fail("The habitat or its recording controls could not be created.")
		return
	var recorder: Variant = _world.get("video_recorder")
	if recorder == null:
		_fail("The local video recorder is unavailable.")
		return
	recorder.set("recordings_directory", REVIEW_RECORDINGS_DIRECTORY)
	var moss_profile: Variant = _world.call("profile_for", "moss")
	if moss_profile != null and moss_profile.get("actor") != null:
		moss_profile.get("actor").set_physics_process(false)
	_world.set("simulation_speed", 0.5)
	_world.call("select_norn", "mallow")
	for frame in range(12):
		await process_frame
	_world.call("toggle_recording")
	_recording_started = bool(_world.call("is_recording"))
	if not _recording_started:
		_fail("The expanded-habitat recording did not start.")
		return

	if not await _guide_until("fruit", "ate honey fruit", 1200):
		_fail("Mallow did not reach honey fruit during the recording.")
		return
	_world.call("give_feedback", "praise")
	for frame in range(12):
		await process_frame
	if not await _guide_until("berry_bush", "foraged berries", 1500):
		_fail("Mallow did not reach the berry bush during the recording.")
		return
	for frame in range(12):
		await process_frame

	var mallow: Variant = _world.call("profile_for", "mallow")
	var biology: Dictionary = mallow.get("biochemistry_state")
	var compounds: Dictionary = Biochemistry.read_compounds(biology)
	compounds["thirst"] = 85.0
	biology["compounds"] = compounds
	if not Cognition.sync_chemistry(mallow.get("cognition_state"), Biochemistry.read_signals(biology)):
		_fail("The spring walkthrough could not set a bounded thirst cue.")
		return
	_world.call("_refresh_ui")

	if not await _guide_until("spinner", "played with the spinner", 1500):
		_fail("Mallow did not reach the spinner during the recording.")
		return
	if not await _guide_until("spring", "drank from the spring", 1500):
		_fail("Mallow did not reach the spring during the recording.")
		return
	if not await _guide_until("route_marker_7", "explored curiosity marker", 900):
		_fail("Mallow did not discover the Glassfall curiosity trail marker during the recording.")
		return
	if not await _guide_until("echo_bloom", "explored echo bloom", 900):
		_fail("Mallow did not reach the echo bloom during the recording.")
		return
	for frame in range(36):
		await process_frame

	_world.call("toggle_recording")
	_recording_started = false
	await process_frame
	var frame_count := int(_world.get("recorded_frame_count"))
	var video_path := str(_world.get("last_recording_path"))
	if frame_count < 2 or video_path.is_empty() or not FileAccess.file_exists(video_path):
		_fail("The expanded-habitat AVI did not finalize successfully.")
		return
	if not _restore_user_save():
		_fail("The preview finished, but the original local save could not be restored.")
		return
	print("HABITAT_PREVIEW_READY frames=%d path=%s walkthrough=sunmeadow-berry-forage-glassfall-spinner-spring-exploration-echo-bloom" % [frame_count, video_path])
	quit()


func _guide_until(object_id: String, completion_text: String, max_frames: int) -> bool:
	var guided := false
	for frame_index in range(max_frames):
		if str(_world.get("last_status")).to_lower().contains(completion_text.to_lower()):
			return true
		if not guided:
			_world.call("guide_to", object_id)
			guided = true
		await process_frame
	return str(_world.get("last_status")).to_lower().contains(completion_text.to_lower())


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


func _restore_user_save() -> bool:
	if not _save_backup_ready:
		return false
	if _previous_save_exists:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file == null:
			return false
		file.store_string(_previous_save_text)
		file.close()
	else:
		var absolute_path := ProjectSettings.globalize_path(SAVE_PATH)
		if FileAccess.file_exists(SAVE_PATH) and DirAccess.remove_absolute(absolute_path) != OK:
			return false
	_save_backup_ready = false
	return true


func _fail(message: String) -> void:
	if _recording_started and _world != null and _world.has_method("is_recording") and bool(_world.call("is_recording")):
		_world.call("toggle_recording")
	_recording_started = false
	if _save_backup_ready and not _restore_user_save():
		push_error("The original local save could not be restored after preview failure.")
	push_error("HABITAT_PREVIEW_FAILED: " + message)
	quit(1)
