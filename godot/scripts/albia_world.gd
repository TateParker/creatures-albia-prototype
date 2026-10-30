class_name AlbiaWorld
extends Node3D

const Cognition = preload("res://scripts/norn_cognition.gd")
const Biochemistry = preload("res://scripts/norn_biochemistry.gd")
const HabitatUi = preload("res://scripts/habitat_ui.gd")
const NornLanguageScript = preload("res://scripts/norn_language.gd")
const VideoRecorder = preload("res://scripts/local_video_recorder.gd")
const NornProfile = preload("res://scripts/norn_profile.gd")
const NornLifecycle = preload("res://scripts/norn_lifecycle.gd")
const NornEggScript = preload("res://scripts/norn_egg.gd")
const DrawingSurfaceScript = preload("res://scripts/drawing_surface.gd")
const START_SEED := 4181996
const MOSS_SEED := 4181997
const SAVE_PATH := "user://albia_norn_save.json"
const SAVE_VERSION := 8
const STARTER_PROFILE_IDS: Array[String] = ["mallow", "moss"]
const MALLOW_COLOR := Color(0.43, 0.27, 0.16)
const MOSS_COLOR := Color(0.24, 0.42, 0.34)
const MAX_POPULATION := 4
const CHILD_NAMES: Array[String] = ["Sprout", "Clover", "Acorn", "Pip"]
const CHEMISTRY_STEP := 0.1
const DECISION_STEP := 0.2
const FEEDBACK_WINDOW := 12.0
const SENSE_RADIUS := 10.0
const OBSERVATION_RADIUS := 3.0
const DRAWING_SURFACE_ID := "drawing_surface"
const DRAWING_TOOL_ID := "charcoal"
const DRAWING_SURFACE_WIDTH := 2.2
const DRAWING_SURFACE_HEIGHT := 1.45

var norn: NornActor
var moss: NornActor
var norn_profiles: Dictionary = {}
var eggs: Array[Dictionary] = []
var next_norn_number: int = 1
var focused_norn_id: String = "mallow"
var objects: Dictionary = {}
var cognition_state: Dictionary = {}
var biochemistry_state: Dictionary = {}
var language_state: Dictionary = {}
var teaching_mode: bool = false
var current_decision: Dictionary = {}
var recalled_moments: Array[Dictionary] = []
var simulation_time: float = 0.0
var simulation_speed: float = 1.0
var paused: bool = false
var guidance: Dictionary = {}
var feedback_available: bool = false
var feedback_action: String = ""
var feedback_target: String = ""
var feedback_time: float = -1000.0
var last_status: String = "A new Norn is exploring the habitat."
var video_recorder: LocalVideoRecorder
var drawing_surface: RefCounted

var last_recording_path: String:
	get:
		return video_recorder.last_recording_path if video_recorder != null else ""

var recorded_frame_count: int:
	get:
		return video_recorder.recorded_frame_count if video_recorder != null else 0

var _ui: HabitatUi
var _language: RefCounted
var _camera: Camera3D
var _camera_target := Vector3(3.8, 0.0, 0.0)
var _camera_offset := Vector3(0.0, 11.0, 15.5)
var _camera_follow_enabled := true
var _chemistry_accumulator: float = 0.0
var _decision_accumulator: float = 0.0
var _respawn_times: Dictionary = {}
var _egg_nodes: Dictionary = {}
var _drawing_panel: MeshInstance3D
var _nest_position := Vector3(-1.5, 0.0, -2.8)


func _ready() -> void:
	drawing_surface = DrawingSurfaceScript.new() as RefCounted
	_build_environment()
	_build_habitat()
	_build_camera()
	_build_creature()
	_build_objects()
	_language = NornLanguageScript.new()
	_create_profiles()
	video_recorder = VideoRecorder.new()
	video_recorder.name = "LocalVideoRecorder"
	add_child(video_recorder)
	_ui = HabitatUi.new()
	add_child(_ui)
	_ui.setup(self)
	_refresh_ui()


func _process(delta: float) -> void:
	if paused:
		_refresh_ui()
		return
	var step_delta := minf(maxf(0.0, delta * simulation_speed), 0.5)
	var tick_profiles := living_profiles()
	simulation_time += step_delta
	_chemistry_accumulator = minf(_chemistry_accumulator + step_delta, CHEMISTRY_STEP * 5.0)
	_decision_accumulator = minf(_decision_accumulator + step_delta, DECISION_STEP * 3.0)
	var chemistry_steps := 0
	while _chemistry_accumulator >= CHEMISTRY_STEP and chemistry_steps < 5:
		for profile: NornProfile in tick_profiles:
			_step_profile_chemistry(profile)
		_chemistry_accumulator -= CHEMISTRY_STEP
		chemistry_steps += 1
	var decision_steps := 0
	while _decision_accumulator >= DECISION_STEP and decision_steps < 3:
		_decision_accumulator -= DECISION_STEP
		decision_steps += 1
		for profile: NornProfile in tick_profiles:
			_run_decision(profile)
	_tick_eggs(step_delta)
	_update_timed_state()
	for profile: NornProfile in tick_profiles:
		_step_lifecycle(profile, step_delta)
	_update_camera()
	_refresh_ui()


func guide_to(object_id: String) -> void:
	if not objects.has(object_id):
		return
	var item: Interactable = objects[object_id]
	if not item.available:
		last_status = "%s is having a short rest." % item.display_name
		_refresh_ui()
		return
	var profile := focused_profile()
	if profile == null:
		return
	profile.guidance = {"objectId": object_id}
	_camera_follow_enabled = true
	_update_camera()
	if profile.actor_id == "mallow":
		guidance = profile.guidance
	last_status = "You pointed toward %s for %s." % [item.display_name, profile.display_name]
	_run_decision(profile)
	_refresh_ui()


func give_feedback(feedback: String) -> void:
	if teaching_mode:
		last_status = "Teach mode is on. Choose the word's meaning with the target buttons."
		_refresh_ui()
		return
	if not ["praise", "scold"].has(feedback):
		return
	var profile := focused_profile()
	if profile == null:
		return
	if not profile.feedback_available or simulation_time - profile.feedback_time > FEEDBACK_WINDOW:
		last_status = "Wait for %s to use an item or explore, then respond within 12 seconds." % profile.display_name
		_refresh_ui()
		return
	var feedback_word: Dictionary = _language.call("word_for_target", profile.language_state, feedback)
	var outcome := {
		"eventType": feedback,
		"actionId": profile.feedback_action,
		"targetId": profile.feedback_target if not profile.feedback_target.is_empty() else feedback,
		"actorId": profile.actor_id,
		"time": simulation_time,
		"feedback": feedback,
		"text": "You %s %s after %s." % [feedback, profile.display_name, profile.feedback_action]
	}
	if not feedback_word.is_empty():
		outcome["word"] = str(feedback_word["word"])
	var result: Dictionary = _apply_profile_biochemistry_event(profile, feedback, outcome)
	outcome["eventId"] = int(result.get("episodeId", 0))
	profile.feedback_available = false
	profile.actor.play_response_animation(feedback)
	_offer_observation(profile, outcome)
	_sync_mallow_compatibility()
	var amount := float(result.get("learningDelta", 0.0))
	var feedback_result := "praised" if feedback == "praise" else "scolded"
	var language_delta := 0.14 if feedback == "praise" else -0.14
	var adjusted_words: Array = _language.call("adjust_target", profile.language_state, profile.feedback_target, language_delta)
	last_status = "%s was %s. %s association %s%.2f." % [
		profile.display_name,
		feedback_result,
		profile.feedback_action.capitalize(),
		"+" if amount >= 0.0 else "",
		amount
	]
	if not adjusted_words.is_empty():
		var changed_word: Dictionary = adjusted_words[0]
		last_status += " %s confidence %.2f." % [str(changed_word["word"]), float(changed_word["confidence"])]
	if not feedback_word.is_empty():
		last_status += " %s said “%s”." % [profile.display_name, str(feedback_word["word"])]
	_refresh_ui()


func toggle_teaching_mode() -> void:
	teaching_mode = not teaching_mode
	if teaching_mode:
		last_status = "Teach mode is on. Type one word, then choose a resource, landmark, Praise, or Scold."
	else:
		last_status = "Teach mode cancelled."
		if _ui != null:
			_ui.clear_teaching_input()
	_refresh_ui()


func select_hud_target(target_id: String, input_word: String = "") -> void:
	if teaching_mode:
		teach_word(input_word, target_id)
		return
	if objects.has(target_id):
		guide_to(target_id)
	elif target_id == "praise" or target_id == "scold":
		give_feedback(target_id)


func teach_word(input_word: String, target_id: String) -> void:
	if not teaching_mode:
		last_status = "Choose Teach word before pairing a word with a target."
		_refresh_ui()
		return
	var profile := focused_profile()
	if profile == null:
		return
	var result: Dictionary = _language.call("teach_word", profile.language_state, input_word, target_id)
	if not bool(result.get("ok", false)):
		last_status = str(result.get("error", "That word could not be taught."))
		_refresh_ui()
		return
	var word := str(result.get("word", ""))
	var confidence := float(result.get("confidence", 0.0))
	var target_name := _language_target_name(target_id)
	var readiness := " %s can now use it." % profile.display_name if confidence >= 0.60 else " Teach again or praise correct use to build confidence."
	last_status = "Taught “%s” to %s for %s (%.2f confidence).%s" % [word, target_name, profile.display_name, confidence, readiness]
	_apply_profile_biochemistry_event(profile, "teach-word", {
		"eventType": "teach-word",
		"targetId": target_id,
		"time": simulation_time,
		"word": word,
		"actorId": profile.actor_id,
		"text": "%s learned “%s” for %s." % [profile.display_name, word, target_name]
	})
	_sync_mallow_compatibility()
	_refresh_ui()


func _language_target_name(target_id: String) -> String:
	match target_id:
		"fruit":
			return "honey fruit"
		"spinner":
			return "the wind-up spinner"
		"berry_bush":
			return "the berry bush"
		"spring":
			return "the spring"
		"echo_bloom":
			return "the echo bloom"
		"praise":
			return "Praise"
		"scold":
			return "Scold"
	return "that target"


func toggle_pause() -> void:
	paused = not paused
	for profile: NornProfile in norn_profiles.values():
		if profile.actor != null:
			profile.actor.set_physics_process(not paused)
	last_status = "Simulation paused." if paused else "Simulation resumed."
	_refresh_ui()


func cycle_speed() -> void:
	if is_equal_approx(simulation_speed, 0.5):
		simulation_speed = 1.0
	elif is_equal_approx(simulation_speed, 1.0):
		simulation_speed = 2.0
	else:
		simulation_speed = 0.5
	last_status = "Simulation speed: %.1f×." % simulation_speed
	_refresh_ui()


func toggle_recording() -> void:
	if video_recorder == null:
		last_status = "Local video recording is unavailable."
		_refresh_ui()
		return
	if video_recorder.is_recording():
		var stop_error: Error = video_recorder.stop_recording()
		if stop_error == OK:
			var retention_status := ""
			if video_recorder.last_pruned_clip_count > 0:
				var clip_word := "clip" if video_recorder.last_pruned_clip_count == 1 else "clips"
				retention_status = " Replaced %d oldest %s to keep 10." % [video_recorder.last_pruned_clip_count, clip_word]
			last_status = "Saved the habitat video locally to %s.%s" % [last_recording_path, retention_status]
		else:
			last_status = video_recorder.last_error
	else:
		var start_error: Error = video_recorder.start_recording()
		if start_error == OK:
			last_status = "Recording the habitat locally at 720p and 15 FPS."
		else:
			last_status = video_recorder.last_error
	_refresh_ui()


func is_recording() -> bool:
	return video_recorder != null and video_recorder.is_recording()


func open_recordings_folder() -> void:
	if video_recorder == null:
		return
	var open_error: Error = video_recorder.open_recordings_folder()
	last_status = "Opening the local recordings folder." if open_error == OK else video_recorder.last_error
	_refresh_ui()


func save_game() -> void:
	var saved_norns := {}
	for actor_id: String in ordered_profile_ids():
		var saved_profile := _serialize_profile(profile_for(actor_id))
		if saved_profile.is_empty():
			last_status = "The local %s profile failed validation and could not be saved." % actor_id.capitalize()
			_refresh_ui()
			return
		saved_norns[actor_id] = saved_profile
	var saved_eggs: Array[Dictionary] = []
	for index in range(eggs.size()):
		var egg_record: Dictionary = eggs[index].duplicate(true)
		var egg_id := str(egg_record.get("eggId", ""))
		var egg_node: Variant = _egg_nodes.get(egg_id, null)
		if egg_node is Node3D:
			var serialized_egg: Variant = (egg_node as Node3D).call("serialize_state")
			if serialized_egg is Dictionary:
				egg_record = serialized_egg
			eggs[index] = egg_record
		if egg_record.is_empty():
			last_status = "A local egg record failed validation and could not be saved."
			_refresh_ui()
			return
		saved_eggs.append(egg_record)
	var record := {
		"version": SAVE_VERSION,
		"seed": START_SEED,
		"simulationTime": simulation_time,
		"focusedNornId": focused_norn_id,
		"nextNornNumber": next_norn_number,
		"norns": saved_norns,
		"eggs": saved_eggs,
		"drawingSurface": drawing_surface.call("serialize_state") if drawing_surface != null else DrawingSurfaceScript.new().call("serialize_state")
	}
	if _restore_version8_record(record, maxf(0.0, simulation_time)).is_empty():
		last_status = "The local Norn family failed validation and could not be saved."
		_refresh_ui()
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		last_status = "Could not write local save (error %d)." % FileAccess.get_open_error()
		_refresh_ui()
		return
	file.store_string(JSON.stringify(record, "\t"))
	file.close()
	last_status = "Saved the Norn family locally to %s." % SAVE_PATH
	_refresh_ui()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_reset_state(false)
		last_status = "No local save was found; started a clean seeded Norn."
		_refresh_ui()
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_fallback_from_invalid_save("The local save could not be read")
		return
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		_fallback_from_invalid_save("The save format is not valid")
		return
	var record = parser.data
	if not (record is Dictionary):
		_fallback_from_invalid_save("The save format is not valid")
		return
	var version_value = record.get("version", null)
	if not _is_finite_number(version_value) or not is_equal_approx(float(version_value), roundf(float(version_value))) or not [1, 2, 3, 4, 5, 6, 7, SAVE_VERSION].has(int(version_value)):
		_fallback_from_invalid_save("The save format is not valid")
		return
	var save_version := int(version_value)
	var simulation_value = record.get("simulationTime", null)
	var saved_seed = record.get("seed", null)
	if not _is_finite_number(saved_seed) or not is_equal_approx(float(saved_seed), float(START_SEED)) or not _is_finite_number(simulation_value) or float(simulation_value) < 0.0:
		_fallback_from_invalid_save("The save metadata is not valid")
		return
	var candidate: Dictionary
	if save_version == SAVE_VERSION:
		candidate = _restore_version8_record(record, float(simulation_value))
	elif save_version == 7:
		candidate = _restore_version7_record(record, float(simulation_value))
	elif save_version == 6:
		candidate = _restore_version6_record(record, float(simulation_value))
	elif save_version == 5:
		candidate = _restore_version5_record(record, float(simulation_value))
	elif save_version == 4:
		candidate = _restore_version4_record(record, float(simulation_value))
	else:
		candidate = _restore_legacy_record(record, save_version, float(simulation_value))
	if candidate.is_empty():
		_fallback_from_invalid_save("The saved Norn family failed validation")
		return
	_apply_restored_world(candidate, float(simulation_value))
	teaching_mode = false
	if _ui != null:
		_ui.clear_teaching_input()
	_chemistry_accumulator = 0.0
	_decision_accumulator = 0.0
	_respawn_times.clear()
	for item: Interactable in objects.values():
		item.set_available(true)
	_sync_mallow_compatibility()
	last_status = "Loaded the local Norn family and its memories." if save_version == SAVE_VERSION else "Migrated the local Norn family and its memories."
	_refresh_ui()


func _serialize_profile(profile: NornProfile) -> Dictionary:
	if profile == null or not _is_valid_profile_id(profile.actor_id):
		return {}
	var saved_cognition: Dictionary = Cognition.serialize_state(profile.cognition_state)
	var saved_biochemistry: Dictionary = Biochemistry.serialize_state(profile.biochemistry_state)
	var saved_language: Dictionary = _language.call("serialize_state", profile.language_state)
	var saved_life_state: Dictionary = NornLifecycle.serialize_state(profile.life_state)
	var saved_parent_ids: Array[String] = profile.parent_ids.duplicate()
	var saved_color: Array[float] = [profile.body_color.r, profile.body_color.g, profile.body_color.b, profile.body_color.a]
	var saved_feedback := {
		"available": profile.feedback_available,
		"action": profile.feedback_action,
		"target": profile.feedback_target,
		"time": profile.feedback_time
	}
	var serialized := {
		"actorId": profile.actor_id,
		"displayName": profile.display_name,
		"generation": profile.generation,
		"parentIds": saved_parent_ids,
		"bodyColor": saved_color,
		"lifeState": saved_life_state,
		"cognition": saved_cognition,
		"biochemistry": saved_biochemistry,
		"language": saved_language,
		"feedback": saved_feedback,
		"exploredLandmarks": _serialized_exploration_targets(profile.explored_landmarks)
	}
	if profile.actor != null and is_instance_valid(profile.actor):
		var actor_position := profile.actor.global_position
		if not _is_valid_world_position(actor_position):
			return {}
		serialized["position"] = [actor_position.x, actor_position.y, actor_position.z]
	if saved_cognition.is_empty() or saved_biochemistry.is_empty() or saved_language.is_empty() or saved_life_state.is_empty() or _restore_profile(serialized, profile.actor_id, maxf(0.0, simulation_time)).is_empty():
		return {}
	return serialized


func _restore_profile(value: Variant, actor_id: String, saved_simulation_time: float) -> Dictionary:
	if not (value is Dictionary) or not _is_valid_profile_id(actor_id):
		return {}
	var saved: Dictionary = value
	if saved.get("actorId", null) != actor_id:
		return {}
	var display_name = saved.get("displayName", null)
	var generation_value = saved.get("generation", null)
	var raw_parent_ids = saved.get("parentIds", null)
	var raw_body_color = saved.get("bodyColor", null)
	var body_color := _restore_body_color(saved.get("bodyColor", null))
	var restored_position: Variant = null
	if saved.has("position"):
		restored_position = _restore_world_position(saved.get("position", null))
		if not (restored_position is Vector3):
			return {}
	var raw_explored: Variant = saved.get("exploredLandmarks", [])
	if not (raw_explored is Array) or raw_explored.size() > 9:
		return {}
	var explored_landmarks: Dictionary = {}
	for target_value: Variant in raw_explored:
		if not (target_value is String) or not _is_exploration_landmark_id(target_value) or explored_landmarks.has(target_value):
			return {}
		explored_landmarks[target_value] = true
	var life_state: Dictionary = NornLifecycle.restore_state(saved.get("lifeState", null))
	if not (display_name is String) or display_name.strip_edges().is_empty() or display_name.length() > 40:
		return {}
	if not _is_finite_number(generation_value) or not is_equal_approx(float(generation_value), roundf(float(generation_value))) or int(generation_value) < 0:
		return {}
	if not (raw_parent_ids is Array) or not (raw_body_color is Array) or body_color == Color.TRANSPARENT or body_color.a <= 0.0 or life_state.is_empty():
		return {}
	var parent_ids: Array[String] = []
	for parent_value: Variant in raw_parent_ids:
		if not (parent_value is String) or not _is_valid_profile_id(parent_value):
			return {}
		parent_ids.append(parent_value)
	var saved_cognition = saved.get("cognition", null)
	if not (saved_cognition is Dictionary):
		return {}
	var restored_cognition: Dictionary = Cognition.restore_state(saved_cognition)
	var restored_seed = restored_cognition.get("seed", null)
	if restored_cognition.is_empty() or not _is_finite_number(restored_seed):
		return {}
	if actor_id == "mallow" and not is_equal_approx(float(restored_seed), float(START_SEED)):
		return {}
	if actor_id == "moss" and not is_equal_approx(float(restored_seed), float(MOSS_SEED)):
		return {}
	var expected_life: Dictionary = NornLifecycle.create_state(int(restored_seed), 0.0)
	if expected_life.is_empty() or not is_equal_approx(float(expected_life["lifespanSeconds"]), float(life_state["lifespanSeconds"])):
		return {}
	var death: Dictionary = life_state["death"]
	if not death.is_empty() and float(death["simulationTime"]) > saved_simulation_time:
		return {}
	var restored_biochemistry: Dictionary = Biochemistry.restore_state(saved.get("biochemistry", null))
	if restored_biochemistry.is_empty():
		return {}
	var restored_language: Dictionary = _language.call("restore_state", saved.get("language", null))
	if restored_language.is_empty():
		return {}
	var restored_feedback := _restore_feedback(saved.get("feedback", null), saved_simulation_time)
	if restored_feedback.is_empty():
		return {}
	if not Cognition.sync_chemistry(restored_cognition, Biochemistry.read_signals(restored_biochemistry)):
		return {}
	return {
		"actorId": actor_id,
		"displayName": display_name,
		"generation": int(generation_value),
		"parentIds": parent_ids,
		"bodyColor": body_color,
		"position": restored_position,
		"lifeState": life_state,
		"cognition": restored_cognition,
		"biochemistry": restored_biochemistry,
		"language": restored_language,
		"feedback": restored_feedback,
		"exploredLandmarks": explored_landmarks
	}


func _restore_version5_record(record: Dictionary, saved_simulation_time: float) -> Dictionary:
	var saved_norns = record.get("norns", null)
	var saved_focus = record.get("focusedNornId", null)
	var saved_next_number = record.get("nextNornNumber", null)
	var saved_eggs = record.get("eggs", null)
	if not (saved_norns is Dictionary) or saved_norns.size() < STARTER_PROFILE_IDS.size() or not (saved_focus is String):
		return {}
	if not _is_finite_number(saved_next_number) or not is_equal_approx(float(saved_next_number), roundf(float(saved_next_number))) or int(saved_next_number) < 1:
		return {}
	if not (saved_eggs is Array):
		return {}
	var restored_profiles: Dictionary = {}
	var names: Dictionary = {}
	var highest_child_number := 0
	var living_count := 0
	for key: Variant in saved_norns:
		if not (key is String) or not _is_valid_profile_id(key):
			return {}
		var restored_profile := _restore_profile(saved_norns.get(key, null), key, saved_simulation_time)
		if restored_profile.is_empty():
			return {}
		restored_profiles[key] = restored_profile
		if bool(restored_profile["lifeState"]["alive"]):
			if names.has(restored_profile["displayName"]):
				return {}
			names[restored_profile["displayName"]] = true
			living_count += 1
		if str(key).begins_with("norn-"):
			highest_child_number = maxi(highest_child_number, _profile_number(str(key)))
	if not restored_profiles.has("mallow") or not restored_profiles.has("moss"):
		return {}
	for actor_id: String in restored_profiles:
		var profile: Dictionary = restored_profiles[actor_id]
		var parents: Array[String] = profile["parentIds"]
		if STARTER_PROFILE_IDS.has(actor_id):
			if int(profile["generation"]) != 0 or not parents.is_empty():
				return {}
		elif parents.size() != 2 or parents[0] == parents[1] or parents.has(actor_id):
			return {}
		else:
			if not restored_profiles.has(parents[0]) or not restored_profiles.has(parents[1]):
				return {}
			var first_parent: Dictionary = restored_profiles[parents[0]]
			var second_parent: Dictionary = restored_profiles[parents[1]]
			var expected_generation := maxi(int(first_parent["generation"]), int(second_parent["generation"])) + 1
			if int(profile["generation"]) != expected_generation:
				return {}
	var restored_eggs: Array[Dictionary] = []
	var seen_egg_ids: Dictionary = {}
	var reserved_child_ids: Dictionary = {}
	for raw_egg: Variant in saved_eggs:
		var restored_egg := _restore_egg_record(raw_egg, restored_profiles)
		if restored_egg.is_empty():
			return {}
		var egg_id := str(restored_egg["eggId"])
		var child_id := str(restored_egg["childId"])
		var child_name := str(restored_egg["displayName"])
		if seen_egg_ids.has(egg_id) or reserved_child_ids.has(child_id) or restored_profiles.has(child_id) or names.has(child_name):
			return {}
		seen_egg_ids[egg_id] = true
		reserved_child_ids[child_id] = true
		names[child_name] = true
		restored_eggs.append(restored_egg)
		highest_child_number = maxi(highest_child_number, _profile_number(child_id))
	if int(saved_next_number) <= highest_child_number:
		return {}
	if living_count + restored_eggs.size() > MAX_POPULATION:
		return {}
	if living_count == 0:
		if not saved_focus.is_empty():
			return {}
	elif not restored_profiles.has(saved_focus) or not bool(restored_profiles[saved_focus]["lifeState"]["alive"]):
		return {}
	return {
		"profiles": restored_profiles,
		"focusedNornId": saved_focus,
		"nextNornNumber": int(saved_next_number),
		"eggs": restored_eggs
	}


func _restore_version6_record(record: Dictionary, saved_simulation_time: float) -> Dictionary:
	var record_version: Variant = record.get("version", null)
	if not _is_finite_number(record_version) or not is_equal_approx(float(record_version), 6.0):
		return {}
	var candidate := _restore_version5_record(record, saved_simulation_time)
	if candidate.is_empty():
		return {}
	var surface_candidate: RefCounted = DrawingSurfaceScript.new() as RefCounted
	if not bool(surface_candidate.call("restore_state", record.get("drawingSurface", null))):
		return {}
	candidate["drawingSurface"] = surface_candidate.call("serialize_state")
	return candidate


func _restore_version7_record(record: Dictionary, saved_simulation_time: float) -> Dictionary:
	var record_version: Variant = record.get("version", null)
	if not _is_finite_number(record_version) or not is_equal_approx(float(record_version), 7.0):
		return {}
	var candidate := _restore_version6_record(record.merged({"version": 6}, true), saved_simulation_time)
	if candidate.is_empty():
		return {}
	return candidate


func _restore_version8_record(record: Dictionary, saved_simulation_time: float) -> Dictionary:
	var record_version: Variant = record.get("version", null)
	if not _is_finite_number(record_version) or not is_equal_approx(float(record_version), 8.0):
		return {}
	var candidate := _restore_version7_record(record.merged({"version": 7}, true), saved_simulation_time)
	if candidate.is_empty():
		return {}
	var restored_profiles: Dictionary = candidate.get("profiles", {})
	var saved_norns: Dictionary = record.get("norns", {})
	for actor_id: String in restored_profiles:
		var profile: Dictionary = restored_profiles[actor_id]
		var saved_profile: Dictionary = saved_norns.get(actor_id, {})
		if not saved_profile.has("exploredLandmarks"):
			return {}
		if bool(profile["lifeState"]["alive"]) and not (profile.get("position", null) is Vector3):
			return {}
	return candidate


func _restore_world_position(value: Variant) -> Variant:
	if not (value is Array) or value.size() != 3:
		return null
	for coordinate: Variant in value:
		if not _is_finite_number(coordinate):
			return null
	var position := Vector3(float(value[0]), float(value[1]), float(value[2]))
	return position if _is_valid_world_position(position) else null


func _is_valid_world_position(position: Vector3) -> bool:
	return (
		position.x >= NornActor.WORLD_MIN_X and position.x <= NornActor.WORLD_MAX_X
		and position.y >= -1.0 and position.y <= 2.0
		and position.z >= NornActor.WORLD_MIN_Z and position.z <= NornActor.WORLD_MAX_Z
	)


func _is_exploration_landmark_id(target_id: String) -> bool:
	if target_id == "echo_bloom":
		return true
	if not target_id.begins_with("route_marker_"):
		return false
	var marker_number := target_id.trim_prefix("route_marker_")
	return marker_number.is_valid_int() and int(marker_number) >= 1 and int(marker_number) <= 8 and marker_number == str(int(marker_number))


func _serialized_exploration_targets(targets: Dictionary) -> Array[String]:
	var target_ids: Array[String] = []
	for target_id: Variant in targets.keys():
		if target_id is String and _is_exploration_landmark_id(target_id):
			target_ids.append(target_id)
	target_ids.sort()
	return target_ids


func _restore_egg_record(value: Variant, restored_profiles: Dictionary) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var saved: Dictionary = value
	var egg_id = saved.get("eggId", null)
	var child_id = saved.get("childId", null)
	var display_name = saved.get("displayName", null)
	var raw_parent_ids = saved.get("parentIds", null)
	var generation_value = saved.get("generation", null)
	var saved_traits = saved.get("traits", null)
	var raw_color = saved.get("bodyColor", null)
	var seed_value = saved.get("childSeed", null)
	var remaining_value = saved.get("remainingSeconds", null)
	if not (egg_id is String) or not egg_id.begins_with("egg-") or not (child_id is String) or not (display_name is String) or display_name.strip_edges().is_empty() or display_name.length() > 40:
		return {}
	var suffix: String = egg_id.trim_prefix("egg-")
	if not suffix.is_valid_int() or int(suffix) < 1 or suffix != str(int(suffix)) or child_id != "norn-%d" % int(suffix):
		return {}
	if not (raw_parent_ids is Array) or raw_parent_ids.size() != 2:
		return {}
	var parent_ids: Array[String] = []
	for parent_id: Variant in raw_parent_ids:
		if not (parent_id is String) or not restored_profiles.has(parent_id):
			return {}
		parent_ids.append(parent_id)
	if parent_ids[0] == parent_ids[1]:
		return {}
	if not _is_finite_number(generation_value) or not is_equal_approx(float(generation_value), roundf(float(generation_value))) or int(generation_value) < 1:
		return {}
	var first_parent: Dictionary = restored_profiles[parent_ids[0]]
	var second_parent: Dictionary = restored_profiles[parent_ids[1]]
	if int(generation_value) != maxi(int(first_parent["generation"]), int(second_parent["generation"])) + 1:
		return {}
	if not (saved_traits is Dictionary) or saved_traits.size() != 2:
		return {}
	var curiosity = saved_traits.get("curiosity", null)
	var sociability = saved_traits.get("sociability", null)
	if not _is_finite_number(curiosity) or not _is_finite_number(sociability) or float(curiosity) < 0.05 or float(curiosity) > 0.95 or float(sociability) < 0.05 or float(sociability) > 0.95:
		return {}
	var body_color := _restore_body_color(raw_color)
	if not (raw_color is Array) or body_color == Color.TRANSPARENT or body_color.a <= 0.0:
		return {}
	if not _is_finite_number(seed_value) or not is_equal_approx(float(seed_value), roundf(float(seed_value))) or int(seed_value) != _child_seed(int(suffix)):
		return {}
	if not _is_finite_number(remaining_value) or float(remaining_value) < 0.0 or float(remaining_value) > NornEggScript.INCUBATION_SECONDS:
		return {}
	return {
		"eggId": egg_id,
		"childId": child_id,
		"displayName": display_name,
		"parentIds": parent_ids,
		"generation": int(generation_value),
		"traits": {"curiosity": float(curiosity), "sociability": float(sociability)},
		"bodyColor": [body_color.r, body_color.g, body_color.b, body_color.a],
		"childSeed": int(seed_value),
		"remainingSeconds": float(remaining_value)
	}


func _restore_version4_record(record: Dictionary, saved_simulation_time: float) -> Dictionary:
	var saved_norns = record.get("norns", null)
	var saved_focus = record.get("focusedNornId", null)
	if not (saved_norns is Dictionary) or saved_norns.size() != STARTER_PROFILE_IDS.size() or not (saved_focus is String) or not STARTER_PROFILE_IDS.has(saved_focus):
		return {}
	for key: Variant in saved_norns:
		if not (key is String) or not STARTER_PROFILE_IDS.has(key):
			return {}
	var restored_profiles: Dictionary = {}
	for actor_id: String in STARTER_PROFILE_IDS:
		var learning := _restore_profile_learning(saved_norns.get(actor_id, null), actor_id, saved_simulation_time)
		if learning.is_empty():
			return {}
		restored_profiles[actor_id] = _with_founder_defaults(actor_id, learning)
	return {"profiles": restored_profiles, "focusedNornId": saved_focus, "nextNornNumber": 1, "eggs": []}


func _restore_legacy_record(record: Dictionary, save_version: int, saved_simulation_time: float) -> Dictionary:
	var mallow_learning := _restore_legacy_mallow(record, save_version)
	if mallow_learning.is_empty():
		return {}
	var restored_profiles := {
		"mallow": _with_founder_defaults("mallow", mallow_learning),
		"moss": _with_founder_defaults("moss", _make_clean_profile_state("moss"))
	}
	return {"profiles": restored_profiles, "focusedNornId": "mallow", "nextNornNumber": 1, "eggs": []}


func _restore_profile_learning(value: Variant, actor_id: String, saved_simulation_time: float) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var saved: Dictionary = value
	if saved.get("actorId", null) != actor_id:
		return {}
	var saved_cognition = saved.get("cognition", null)
	if not (saved_cognition is Dictionary):
		return {}
	var cognition: Dictionary = Cognition.restore_state(saved_cognition)
	var expected_seed := START_SEED if actor_id == "mallow" else MOSS_SEED
	if cognition.is_empty() or not _is_finite_number(cognition.get("seed", null)) or not is_equal_approx(float(cognition["seed"]), float(expected_seed)):
		return {}
	var biochemistry: Dictionary = Biochemistry.restore_state(saved.get("biochemistry", null))
	var language: Dictionary = _language.call("restore_state", saved.get("language", null))
	var feedback := _restore_feedback(saved.get("feedback", null), saved_simulation_time)
	if biochemistry.is_empty() or language.is_empty() or feedback.is_empty():
		return {}
	if not Cognition.sync_chemistry(cognition, Biochemistry.read_signals(biochemistry)):
		return {}
	return {"cognition": cognition, "biochemistry": biochemistry, "language": language, "feedback": feedback}


func _restore_feedback(value: Variant, saved_simulation_time: float) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var saved: Dictionary = value
	var available = saved.get("available", null)
	var action = saved.get("action", null)
	var target = saved.get("target", null)
	var time = saved.get("time", null)
	if not (available is bool) or not (action is String) or not (target is String) or not _is_finite_number(time):
		return {}
	if action.is_empty() != target.is_empty():
		return {}
	if not action.is_empty() and not _is_valid_feedback_pair(action, target):
		return {}
	if float(time) < -1000.0 or float(time) > saved_simulation_time:
		return {}
	if not action.is_empty() and float(time) < 0.0:
		return {}
	if available and (action.is_empty() or float(time) < 0.0):
		return {}
	return {"available": available, "action": action, "target": target, "time": float(time)}


func _is_valid_feedback_pair(action: String, target: String) -> bool:
	if action == "fruit":
		return target == "fruit"
	if action == "spinner":
		return target == "spinner"
	if action == "forage":
		return target == "berry_bush"
	if action == "drink":
		return target == "spring"
	if action != "explore":
		return false
	if target == "echo_bloom":
		return true
	if not target.begins_with("route_marker_"):
		return false
	var marker_number := target.trim_prefix("route_marker_")
	return marker_number.is_valid_int() and int(marker_number) >= 1 and int(marker_number) <= 8


func _restore_legacy_mallow(record: Dictionary, save_version: int) -> Dictionary:
	var saved_cognition = record.get("cognition", null)
	if not (saved_cognition is Dictionary):
		return {}
	var restored_cognition: Dictionary = Cognition.restore_state(saved_cognition)
	if restored_cognition.is_empty() or int(restored_cognition.get("seed", -1)) != START_SEED:
		return {}
	var restored_biochemistry: Dictionary
	if save_version >= 3:
		restored_biochemistry = Biochemistry.restore_state(record.get("biochemistry", null))
		if restored_biochemistry.is_empty():
			return {}
	else:
		restored_biochemistry = Biochemistry.migrate_from_legacy_signals(restored_cognition["chemistry"])
		if restored_biochemistry.is_empty():
			return {}
	var restored_language: Dictionary = _language.call("create_state")
	if save_version >= 2:
		restored_language = _language.call("restore_state", record.get("language", null))
		if restored_language.is_empty():
			return {}
	if not Cognition.sync_chemistry(restored_cognition, Biochemistry.read_signals(restored_biochemistry)):
		return {}
	return {
		"cognition": restored_cognition,
		"biochemistry": restored_biochemistry,
		"language": restored_language,
		"feedback": {"available": false, "action": "", "target": "", "time": -1000.0}
	}


func _with_founder_defaults(actor_id: String, learning: Dictionary) -> Dictionary:
	var founder := learning.duplicate(true)
	var seed := START_SEED if actor_id == "mallow" else MOSS_SEED
	founder["actorId"] = actor_id
	founder["displayName"] = "Mallow" if actor_id == "mallow" else "Moss"
	founder["generation"] = 0
	founder["parentIds"] = []
	founder["bodyColor"] = MALLOW_COLOR if actor_id == "mallow" else MOSS_COLOR
	founder["lifeState"] = NornLifecycle.create_state(seed, 600.0)
	return founder


func _restore_body_color(value: Variant) -> Color:
	if not (value is Array) or value.size() != 4:
		return Color.TRANSPARENT
	var channels: Array[float] = []
	for channel: Variant in value:
		if not _is_finite_number(channel) or float(channel) < 0.0 or float(channel) > 1.0:
			return Color.TRANSPARENT
		channels.append(float(channel))
	return Color(channels[0], channels[1], channels[2], channels[3])


func _is_valid_profile_id(actor_id: String) -> bool:
	if STARTER_PROFILE_IDS.has(actor_id):
		return true
	if not actor_id.begins_with("norn-"):
		return false
	var suffix := actor_id.trim_prefix("norn-")
	return suffix.is_valid_int() and int(suffix) > 0 and suffix == str(int(suffix))


func _profile_number(actor_id: String) -> int:
	return int(actor_id.trim_prefix("norn-")) if actor_id.begins_with("norn-") else 0


func ordered_profile_ids() -> Array[String]:
	var ordered: Array[String] = []
	for actor_id: String in STARTER_PROFILE_IDS:
		if norn_profiles.has(actor_id):
			ordered.append(actor_id)
	var child_ids: Array[String] = []
	for actor_id: Variant in norn_profiles.keys():
		if actor_id is String and str(actor_id).begins_with("norn-"):
			child_ids.append(str(actor_id))
	child_ids.sort_custom(func(left: String, right: String) -> bool: return _profile_number(left) < _profile_number(right))
	ordered.append_array(child_ids)
	return ordered


func _apply_restored_world(candidate: Dictionary, saved_simulation_time: float) -> void:
	_clear_profile_actors()
	_clear_egg_nodes()
	norn_profiles.clear()
	var restored_profiles: Dictionary = candidate["profiles"]
	var ids: Array[String] = []
	for actor_id: Variant in restored_profiles.keys():
		ids.append(str(actor_id))
	ids.sort_custom(func(left: String, right: String) -> bool:
		var left_starter_index := STARTER_PROFILE_IDS.find(left)
		var right_starter_index := STARTER_PROFILE_IDS.find(right)
		if left_starter_index >= 0 and right_starter_index >= 0:
			return left_starter_index < right_starter_index
		if left_starter_index >= 0:
			return true
		if right_starter_index >= 0:
			return false
		return _profile_number(left) < _profile_number(right)
	)
	for actor_id: String in ids:
		var restored: Dictionary = restored_profiles[actor_id]
		var actor: NornActor
		if bool(restored["lifeState"]["alive"]):
			actor = _spawn_actor(actor_id, str(restored["displayName"]), restored["bodyColor"])
			if restored.get("position", null) is Vector3:
				actor.global_position = restored["position"]
		var profile := NornProfile.new()
		profile.initialize(actor_id, str(restored["displayName"]), actor, restored["cognition"], restored["biochemistry"], restored["language"])
		profile.generation = int(restored["generation"])
		profile.parent_ids.clear()
		for parent_id: String in restored["parentIds"]:
			profile.parent_ids.append(parent_id)
		profile.body_color = restored["bodyColor"]
		profile.life_state = restored["lifeState"].duplicate(true)
		_sync_profile_life_stage(profile)
		profile.feedback_available = bool(restored["feedback"]["available"])
		profile.feedback_action = str(restored["feedback"]["action"])
		profile.feedback_target = str(restored["feedback"]["target"])
		profile.feedback_time = float(restored["feedback"]["time"])
		profile.explored_landmarks = restored.get("exploredLandmarks", {}).duplicate(true)
		norn_profiles[actor_id] = profile
	simulation_time = saved_simulation_time
	focused_norn_id = str(candidate["focusedNornId"])
	next_norn_number = int(candidate["nextNornNumber"])
	eggs.clear()
	for egg: Variant in candidate["eggs"]:
		eggs.append(egg)
	_rebuild_egg_nodes()
	var surface_record: Variant = candidate.get("drawingSurface", null)
	if not (surface_record is Dictionary):
		surface_record = DrawingSurfaceScript.new().call("serialize_state")
	if drawing_surface == null:
		drawing_surface = DrawingSurfaceScript.new() as RefCounted
	drawing_surface.call("restore_state", surface_record)
	_sync_mallow_compatibility()


func _clear_profile_actors() -> void:
	for value: Variant in norn_profiles.values():
		if value is NornProfile:
			var profile: NornProfile = value
			if profile.actor != null and is_instance_valid(profile.actor):
				profile.actor.free()
	norn = null
	moss = null


func _clear_egg_nodes() -> void:
	for value: Variant in _egg_nodes.values():
		if value is Node3D and is_instance_valid(value):
			(value as Node3D).free()
	_egg_nodes.clear()


func _rebuild_egg_nodes() -> void:
	_clear_egg_nodes()
	for index in range(eggs.size()):
		var egg_record: Dictionary = eggs[index]
		var egg_node: Node3D = NornEggScript.new()
		egg_node.call("configure", egg_record)
		egg_node.position = _egg_position(index)
		add_child(egg_node)
		_egg_nodes[str(egg_record.get("eggId", ""))] = egg_node


func _spawn_actor(actor_id: String, display_name: String, color: Color) -> NornActor:
	var actor := NornActor.new()
	actor.configure_identity(actor_id, display_name, color)
	if actor_id == "mallow":
		actor.position = Vector3(3.0, 0.0, 2.0)
		norn = actor
	elif actor_id == "moss":
		actor.position = Vector3(6.2, 0.0, 1.6)
		moss = actor
	else:
		var number := _profile_number(actor_id)
		actor.position = Vector3(2.8 + float((number - 1) % 3) * 1.25, 0.0, -2.4 - float((number - 1) / 3) * 1.2)
	actor.action_completed.connect(_on_action_completed)
	add_child(actor)
	return actor


func _make_clean_profile_state(actor_id: String) -> Dictionary:
	var cognition := _new_cognition_state() if actor_id == "mallow" else _new_moss_cognition_state()
	var biochemistry := Biochemistry.create_state(cognition["chemistry"])
	Cognition.sync_chemistry(cognition, Biochemistry.read_signals(biochemistry))
	return {
		"cognition": cognition,
		"biochemistry": biochemistry,
		"language": _language.call("create_state"),
		"feedback": {"available": false, "action": "", "target": "", "time": -1000.0}
	}


func reset_run() -> void:
	_reset_state(false)
	last_status = "Started a clean Norn with the fixed comparison seed."
	save_game()


func _new_cognition_state() -> Dictionary:
	return Cognition.create_state(START_SEED, {"curiosity": 0.65, "sociability": 0.55}, {
		"hunger": 45.0,
		"curiosity": 45.0,
		"fatigue": 18.0
	})


func _new_moss_cognition_state() -> Dictionary:
	return Cognition.create_state(MOSS_SEED, {"curiosity": 0.50, "sociability": 0.85}, {
		"hunger": 45.0,
		"curiosity": 45.0,
		"fatigue": 18.0
	})


func _step_lifecycle(profile: NornProfile, delta_seconds: float) -> void:
	if profile == null or not bool(profile.life_state.get("alive", false)):
		return
	var transition: Dictionary = NornLifecycle.advance(profile.life_state, delta_seconds, simulation_time)
	if not bool(transition.get("ok", false)):
		return
	if bool(transition.get("stageChanged", false)):
		_sync_profile_life_stage(profile)
	if bool(transition.get("died", false)):
		_handle_norn_death(profile, profile.life_state.get("death", {}))
	elif bool(transition.get("stageChanged", false)):
		save_game()


func _handle_norn_death(profile: NornProfile, death: Dictionary) -> void:
	if profile == null or profile.actor == null or bool(profile.life_state.get("alive", true)):
		return
	var death_status := "%s reached old age and died." % profile.display_name
	var actor := profile.actor
	actor.set_action_target(null, "dead", "Reached the end of its natural lifespan.")
	actor.set_physics_process(false)
	if actor == norn:
		norn = null
	if actor == moss:
		moss = null
	actor.free()
	profile.actor = null
	profile.guidance.clear()
	profile.current_decision.clear()
	profile.recalled_moments.clear()
	profile.feedback_available = false
	profile.feedback_action = ""
	profile.feedback_target = ""
	profile.feedback_time = -1000.0
	var death_time := float(death.get("simulationTime", simulation_time))
	Cognition.record_outcome(profile.cognition_state, {
		"eventType": "death",
		"actorId": profile.actor_id,
		"time": death_time,
		"learningDelta": 0.0,
		"reward": 0.0,
		"salience": 1.0,
		"text": "%s reached old age and died." % profile.display_name
	})
	var focused_profile_died := focused_norn_id == profile.actor_id
	if focused_profile_died:
		if teaching_mode:
			teaching_mode = false
			if _ui != null:
				_ui.clear_teaching_input()
		focused_norn_id = _next_living_profile_id(profile.actor_id)
	last_status = death_status
	_sync_mallow_compatibility()
	save_game()
	last_status = death_status
	_refresh_ui()


func _next_living_profile_id(after_actor_id: String) -> String:
	var ordered_ids := ordered_profile_ids()
	if ordered_ids.is_empty():
		return ""
	var start_index := ordered_ids.find(after_actor_id)
	for offset in range(1, ordered_ids.size() + 1):
		var candidate_id := ordered_ids[posmod(start_index + offset, ordered_ids.size())]
		var candidate := profile_for(candidate_id)
		if candidate != null and bool(candidate.life_state.get("alive", false)) and candidate.actor != null:
			return candidate_id
	return ""


func _sync_profile_life_stage(profile: NornProfile) -> void:
	if profile == null or profile.actor == null:
		return
	profile.actor.set_meta("life_stage", profile.life_stage)
	if profile.actor.has_method("set_life_stage"):
		profile.actor.call("set_life_stage", profile.life_stage)


func profile_for(actor_id: String) -> NornProfile:
	var profile = norn_profiles.get(actor_id, null)
	return profile as NornProfile if profile is NornProfile else null


func living_profiles() -> Array[NornProfile]:
	var living: Array[NornProfile] = []
	for actor_id: String in ordered_profile_ids():
		var profile := profile_for(actor_id)
		if profile != null and bool(profile.life_state.get("alive", false)) and profile.actor != null:
			living.append(profile)
	return living


func population_count() -> int:
	var count := 0
	for profile: NornProfile in norn_profiles.values():
		if bool(profile.life_state.get("alive", false)):
			count += 1
	return count + eggs.size()


func start_egg(second_parent_id: String) -> bool:
	var first_parent := focused_profile()
	var second_parent := profile_for(second_parent_id)
	if first_parent == null or second_parent == null:
		last_status = "Choose two living adult Norns before starting an egg."
		_refresh_ui()
		return false
	if first_parent.actor_id == second_parent.actor_id:
		last_status = "A Norn cannot pair with itself."
		_refresh_ui()
		return false
	for parent: NornProfile in [first_parent, second_parent]:
		var age := float(parent.life_state.get("ageSeconds", -1.0))
		if parent.actor == null or not bool(parent.life_state.get("alive", false)) or age < NornLifecycle.ADOLESCENT_END_SECONDS:
			last_status = "%s must be a living adult before pairing." % parent.display_name
			_refresh_ui()
			return false
	if population_count() >= MAX_POPULATION:
		last_status = "The habitat is full; hatch or free a family slot before pairing again."
		_refresh_ui()
		return false
	var child_number := next_norn_number
	var child_id := "norn-%d" % child_number
	var egg_id := "egg-%d" % child_number
	if norn_profiles.has(child_id) or _egg_nodes.has(egg_id):
		last_status = "The next family ID is already reserved; the clutch was not created."
		_refresh_ui()
		return false
	var first_traits: Dictionary = first_parent.cognition_state.get("traits", {})
	var second_traits: Dictionary = second_parent.cognition_state.get("traits", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = _inheritance_rng_seed(child_number)
	var child_traits := {
		"curiosity": clampf((float(first_traits.get("curiosity", 0.5)) + float(second_traits.get("curiosity", 0.5))) * 0.5 + rng.randf_range(-0.06, 0.06), 0.05, 0.95),
		"sociability": clampf((float(first_traits.get("sociability", 0.5)) + float(second_traits.get("sociability", 0.5))) * 0.5 + rng.randf_range(-0.06, 0.06), 0.05, 0.95)
	}
	var child_color := Color(
		(first_parent.body_color.r + second_parent.body_color.r) * 0.5,
		(first_parent.body_color.g + second_parent.body_color.g) * 0.5,
		(first_parent.body_color.b + second_parent.body_color.b) * 0.5,
		(first_parent.body_color.a + second_parent.body_color.a) * 0.5
	)
	var parent_ids: Array[String] = [first_parent.actor_id, second_parent.actor_id]
	var child_name := _child_display_name(child_number)
	var egg_record := {
		"eggId": egg_id,
		"childId": child_id,
		"displayName": child_name,
		"parentIds": parent_ids,
		"generation": maxi(first_parent.generation, second_parent.generation) + 1,
		"traits": child_traits,
		"bodyColor": [child_color.r, child_color.g, child_color.b, child_color.a],
		"childSeed": _child_seed(child_number),
		"remainingSeconds": NornEggScript.INCUBATION_SECONDS
	}
	var egg_node: Node3D = NornEggScript.new()
	egg_node.call("configure", egg_record)
	egg_node.position = _egg_position(eggs.size())
	add_child(egg_node)
	_egg_nodes[egg_id] = egg_node
	eggs.append(egg_record)
	next_norn_number = child_number + 1
	_record_family_memory(first_parent, [second_parent.actor_id, child_id], "%s and %s began a family egg." % [first_parent.display_name, second_parent.display_name])
	_record_family_memory(second_parent, [first_parent.actor_id, child_id], "%s and %s began a family egg." % [first_parent.display_name, second_parent.display_name])
	last_status = "%s and %s started an egg for %s." % [first_parent.display_name, second_parent.display_name, child_name]
	var event_status := last_status
	save_game()
	last_status = event_status
	_refresh_ui()
	return true


func _child_seed(child_number: int) -> int:
	return int(posmod(START_SEED + child_number * 104729, 0xfffffffe)) + 1


func _inheritance_rng_seed(child_number: int) -> int:
	var seed := (START_SEED ^ (child_number * 0x9e3779b9)) & 0xffffffff
	return seed if seed > 0 else 1


func _child_display_name(child_number: int) -> String:
	var base_name := CHILD_NAMES[posmod(child_number - 1, CHILD_NAMES.size())]
	var in_use := false
	for profile: NornProfile in living_profiles():
		if profile.display_name == base_name:
			in_use = true
			break
	if not in_use:
		for egg_record: Dictionary in eggs:
			if str(egg_record.get("displayName", "")) == base_name:
				in_use = true
				break
	return "%s %d" % [base_name, child_number] if in_use else base_name


func _egg_position(index: int) -> Vector3:
	return _nest_position + Vector3(-0.32 + float(index % 2) * 0.64, 0.22, -0.18 + float(index / 2) * 0.5)


func _record_family_memory(profile: NornProfile, related_norn_ids: Array[String], text_value: String) -> void:
	if profile == null:
		return
	var outcome := {
		"eventType": "family",
		"actorId": profile.actor_id,
		"time": simulation_time,
		"learningDelta": 0.0,
		"reward": 0.0,
		"salience": 0.6,
		"text": text_value
	}
	var result: Dictionary = Cognition.record_outcome(profile.cognition_state, outcome)
	var episode_id := int(result.get("episodeId", 0))
	if episode_id > 0:
		for episode_value: Variant in profile.cognition_state.get("episodes", []):
			if episode_value is Dictionary and int((episode_value as Dictionary).get("id", -1)) == episode_id:
				(episode_value as Dictionary)["relatedNornIds"] = related_norn_ids.duplicate()
				break
	if profile.actor_id == "mallow":
		_sync_mallow_compatibility()


func _tick_eggs(delta_seconds: float) -> void:
	var hatched_ids: Array[String] = []
	for index in range(eggs.size()):
		var egg_id := str(eggs[index].get("eggId", ""))
		var egg_node: Variant = _egg_nodes.get(egg_id, null)
		if not (egg_node is Node3D):
			continue
		var completed := bool((egg_node as Node3D).call("advance", delta_seconds))
		var saved_egg: Variant = (egg_node as Node3D).call("serialize_state")
		if saved_egg is Dictionary:
			eggs[index] = saved_egg
		if completed:
			hatched_ids.append(egg_id)
	for egg_id: String in hatched_ids:
		_hatch_egg(egg_id)


func _hatch_egg(egg_id: String) -> void:
	var egg_node: Variant = _egg_nodes.get(egg_id, null)
	if not (egg_node is Node3D):
		return
	var egg_record_value: Variant = (egg_node as Node3D).call("serialize_state")
	if not (egg_record_value is Dictionary):
		return
	var egg_record: Dictionary = egg_record_value
	var child_id := str(egg_record.get("childId", ""))
	if not _is_valid_profile_id(child_id) or norn_profiles.has(child_id):
		return
	var parent_ids: Array[String] = []
	for parent_id: Variant in egg_record.get("parentIds", []):
		if parent_id is String:
			parent_ids.append(parent_id)
	var child_seed := int(egg_record.get("childSeed", 0))
	var child_traits: Dictionary = egg_record.get("traits", {}).duplicate(true)
	var child_color := _restore_body_color(egg_record.get("bodyColor", null))
	var child_cognition: Dictionary = Cognition.create_state(child_seed, child_traits, {"hunger": 45.0, "curiosity": 45.0, "fatigue": 18.0})
	var child_biochemistry: Dictionary = Biochemistry.create_state(child_cognition["chemistry"])
	Cognition.sync_chemistry(child_cognition, Biochemistry.read_signals(child_biochemistry))
	var child_language: Dictionary = _language.call("create_state")
	var actor := _spawn_actor(child_id, str(egg_record.get("displayName", "Norn")), child_color)
	var child := NornProfile.new()
	child.initialize(child_id, str(egg_record.get("displayName", "Norn")), actor, child_cognition, child_biochemistry, child_language)
	child.generation = int(egg_record.get("generation", 1))
	child.parent_ids.clear()
	for parent_id: String in parent_ids:
		child.parent_ids.append(parent_id)
	child.body_color = child_color
	child.life_state = NornLifecycle.create_state(child_seed, 0.0)
	_sync_profile_life_stage(child)
	norn_profiles[child_id] = child
	var birth_outcome := {
		"eventType": "birth",
		"actorId": child_id,
		"time": simulation_time,
		"learningDelta": 0.0,
		"reward": 0.0,
		"text": "%s hatched to join its family." % child.display_name
	}
	var birth_result: Dictionary = Cognition.record_outcome(child.cognition_state, birth_outcome)
	var birth_episode_id := int(birth_result.get("episodeId", 0))
	if birth_episode_id > 0 and not child.cognition_state["episodes"].is_empty():
		(child.cognition_state["episodes"][-1] as Dictionary)["relatedNornIds"] = parent_ids.duplicate()
	for parent_id: String in parent_ids:
		var parent := profile_for(parent_id)
		if parent != null:
			var other_parent := parent_ids[1] if parent_id == parent_ids[0] else parent_ids[0]
			_record_family_memory(parent, [other_parent, child_id], "%s hatched; %s is now part of the family." % [child.display_name, child.display_name])
	var egg_index := -1
	for index in range(eggs.size()):
		if str(eggs[index].get("eggId", "")) == egg_id:
			egg_index = index
			break
	if egg_index >= 0:
		eggs.remove_at(egg_index)
	_egg_nodes.erase(egg_id)
	(egg_node as Node3D).free()
	var focused := focused_profile()
	if focused == null or not bool(focused.life_state.get("alive", false)):
		focused_norn_id = child_id
	_run_decision(child)
	last_status = "%s hatched from its egg." % child.display_name
	var event_status := last_status
	_sync_mallow_compatibility()
	save_game()
	last_status = event_status
	_refresh_ui()


func focused_profile() -> NornProfile:
	return profile_for(focused_norn_id)


func select_norn(actor_id: String) -> void:
	var profile := profile_for(actor_id)
	if profile == null or profile.actor == null or not bool(profile.life_state.get("alive", false)):
		return
	focused_norn_id = profile.actor_id
	_camera_follow_enabled = true
	_update_camera()
	last_status = "Focused on %s. Player actions will go to %s." % [profile.display_name, profile.display_name]
	_refresh_ui()


func _create_profiles() -> void:
	_clear_profile_actors()
	_clear_egg_nodes()
	norn_profiles.clear()
	eggs.clear()
	next_norn_number = 1
	focused_norn_id = "mallow"
	var mallow_profile := _create_profile("mallow", "Mallow", _spawn_actor("mallow", "Mallow", MALLOW_COLOR), _new_cognition_state())
	var moss_profile := _create_profile("moss", "Moss", _spawn_actor("moss", "Moss", MOSS_COLOR), _new_moss_cognition_state())
	norn_profiles["mallow"] = mallow_profile
	norn_profiles["moss"] = moss_profile
	_sync_mallow_compatibility()
	for profile: NornProfile in norn_profiles.values():
		_run_decision(profile)


func _create_profile(actor_id: String, display_name: String, actor: NornActor, cognition: Dictionary) -> NornProfile:
	var biochemistry := Biochemistry.create_state(cognition["chemistry"])
	Cognition.sync_chemistry(cognition, Biochemistry.read_signals(biochemistry))
	var language: Dictionary = _language.call("create_state")
	var profile := NornProfile.new()
	profile.initialize(actor_id, display_name, actor, cognition, biochemistry, language)
	profile.generation = 0
	profile.parent_ids.clear()
	profile.body_color = MALLOW_COLOR if actor_id == "mallow" else MOSS_COLOR
	profile.life_state = NornLifecycle.create_state(int(cognition["seed"]), 600.0)
	_sync_profile_life_stage(profile)
	return profile


func _sync_mallow_compatibility() -> void:
	var mallow_profile := profile_for("mallow")
	if mallow_profile == null:
		return
	cognition_state = mallow_profile.cognition_state
	biochemistry_state = mallow_profile.biochemistry_state
	language_state = mallow_profile.language_state
	guidance = mallow_profile.guidance
	current_decision = mallow_profile.current_decision
	recalled_moments = mallow_profile.recalled_moments
	feedback_available = mallow_profile.feedback_available
	feedback_action = mallow_profile.feedback_action
	feedback_target = mallow_profile.feedback_target
	feedback_time = mallow_profile.feedback_time


func _apply_biochemistry_event(event_id: String, outcome: Dictionary) -> Dictionary:
	return _apply_profile_biochemistry_event(profile_for("mallow"), event_id, outcome)


func _apply_profile_biochemistry_event(profile: NornProfile, event_id: String, outcome: Dictionary) -> Dictionary:
	if profile == null or profile.cognition_state.is_empty() or profile.biochemistry_state.is_empty():
		return {}
	var before: Dictionary = Biochemistry.read_signals(profile.biochemistry_state)
	var applied: Dictionary = Biochemistry.apply_event(profile.biochemistry_state, event_id)
	if applied.is_empty():
		return {}
	var after: Dictionary = Biochemistry.read_signals(profile.biochemistry_state)
	if not Cognition.sync_chemistry(profile.cognition_state, after):
		return {}
	var result: Dictionary = Cognition.record_outcome(profile.cognition_state, outcome, {"before": before, "after": after})
	if profile.actor_id == "mallow":
		_sync_mallow_compatibility()
	return result


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.14, 0.32, 0.49)
	sky_material.sky_horizon_color = Color(0.66, 0.78, 0.82)
	sky_material.ground_bottom_color = Color(0.18, 0.2, 0.13)
	sky_material.ground_horizon_color = Color(0.53, 0.61, 0.4)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.78, 0.76)
	environment.ambient_light_energy = 0.65
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)


func _build_habitat() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "HabitatFloor"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 1
	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(72.0, 0.4, 18.0)
	floor_mesh.mesh = box
	floor_mesh.material_override = _material(Color(0.20, 0.28, 0.21))
	floor_mesh.position = Vector3(24.0, -0.2, 0.0)
	floor_body.add_child(floor_mesh)
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = box.size
	floor_collision.shape = floor_shape
	floor_collision.position = Vector3(24.0, -0.2, 0.0)
	floor_body.add_child(floor_collision)
	add_child(floor_body)
	var regions: Array[Dictionary] = [
		{"name": "Sunmeadow", "center": 0.0, "color": Color(0.30, 0.43, 0.24)},
		{"name": "Softwood Grove", "center": 24.0, "color": Color(0.24, 0.37, 0.27)},
		{"name": "Glassfall Hollow", "center": 48.0, "color": Color(0.24, 0.36, 0.39)}
	]
	for region: Dictionary in regions:
		var region_mesh := MeshInstance3D.new()
		var region_box := BoxMesh.new()
		region_box.size = Vector3(24.0, 0.025, 18.0)
		region_mesh.mesh = region_box
		region_mesh.position = Vector3(float(region["center"]), 0.016, 0.0)
		region_mesh.material_override = _material(region["color"])
		add_child(region_mesh)
	_add_path(Vector3(24.0, 0.065, 0.0), Vector3(72.0, 0.05, 2.7))
	_add_tree(Vector3(-9.0, 0.0, -5.5), 1.2, Color(0.23, 0.42, 0.25))
	_add_tree(Vector3(-8.5, 0.0, 5.5), 1.0, Color(0.3, 0.48, 0.27))
	_add_tree(Vector3(-5.2, 0.0, -6.4), 0.92, Color(0.35, 0.48, 0.25))
	_add_tree(Vector3(7.8, 0.0, -5.4), 1.1, Color(0.22, 0.4, 0.23))
	_add_tree(Vector3(9.2, 0.0, 5.8), 1.0, Color(0.34, 0.48, 0.24))
	_add_tree(Vector3(15.4, 0.0, -5.8), 1.2, Color(0.18, 0.34, 0.21))
	_add_tree(Vector3(18.3, 0.0, 5.7), 1.4, Color(0.17, 0.31, 0.20))
	_add_tree(Vector3(30.5, 0.0, -5.4), 1.1, Color(0.24, 0.39, 0.23))
	_add_tree(Vector3(33.2, 0.0, 5.7), 1.25, Color(0.19, 0.34, 0.22))
	_add_tree(Vector3(40.3, 0.0, -5.8), 1.0, Color(0.18, 0.32, 0.28))
	_add_tree(Vector3(44.0, 0.0, 5.5), 1.3, Color(0.21, 0.36, 0.32))
	_add_tree(Vector3(55.2, 0.0, -5.8), 1.2, Color(0.24, 0.38, 0.29))
	_add_tree(Vector3(57.0, 0.0, 5.8), 0.95, Color(0.20, 0.34, 0.3))
	_add_rock(Vector3(-5.7, 0.18, -5.8), Vector3(1.1, 0.4, 0.8))
	_add_rock(Vector3(5.6, 0.16, 5.6), Vector3(1.2, 0.35, 0.7))
	_add_rock(Vector3(12.7, 0.2, 5.9), Vector3(1.0, 0.42, 0.75))
	_add_rock(Vector3(22.3, 0.18, -5.5), Vector3(0.9, 0.38, 0.7))
	_add_rock(Vector3(34.0, 0.18, -5.8), Vector3(1.2, 0.45, 0.85))
	_add_rock(Vector3(38.4, 0.18, 5.6), Vector3(1.1, 0.42, 0.78))
	_add_rock(Vector3(59.0, 0.18, 5.6), Vector3(1.15, 0.42, 0.8))
	_add_label("Sunmeadow", Vector3(-9.6, 0.3, -7.7), 28, Color(0.95, 0.88, 0.62))
	_add_label("Softwood Grove", Vector3(14.0, 0.3, -7.7), 28, Color(0.85, 0.94, 0.70))
	_add_label("Glassfall Hollow", Vector3(38.3, 0.3, -7.7), 28, Color(0.75, 0.91, 0.95))
	var nest := Node3D.new()
	nest.name = "FamilyNest"
	nest.position = _nest_position
	var nest_bowl := MeshInstance3D.new()
	nest_bowl.name = "WovenNest"
	var bowl_mesh := CylinderMesh.new()
	bowl_mesh.top_radius = 0.82
	bowl_mesh.bottom_radius = 0.58
	bowl_mesh.height = 0.24
	nest_bowl.mesh = bowl_mesh
	nest_bowl.position.y = 0.1
	nest_bowl.material_override = _material(Color(0.42, 0.29, 0.17))
	nest.add_child(nest_bowl)
	var nest_ring := MeshInstance3D.new()
	nest_ring.name = "NestRim"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.58
	ring_mesh.outer_radius = 0.78
	nest_ring.mesh = ring_mesh
	nest_ring.position.y = 0.2
	nest_ring.material_override = _material(Color(0.55, 0.38, 0.2))
	nest.add_child(nest_ring)
	add_child(nest)
	_add_label("Norn nest", _nest_position + Vector3(-0.65, 0.55, -0.55), 16, Color(0.96, 0.85, 0.59))


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "HabitatCamera"
	_camera.current = true
	_camera.fov = 48.0
	add_child(_camera)
	_update_camera()


func _build_creature() -> void:
	norn = null
	moss = null


func _build_objects() -> void:
	var fruit := Interactable.new()
	fruit.name = "HoneyFruit"
	fruit.configure("fruit", "food", "Honey fruit", ["eat"])
	fruit.position = Vector3(0.8, 0.0, 1.8)
	fruit.collision_layer = 2
	fruit.collision_mask = 0
	var fruit_visuals := Node3D.new()
	var fruit_material := _material(Color(1.0, 0.56, 0.12))
	_add_sphere_mesh(fruit_visuals, "Fruit", Vector3(0.0, 0.72, 0.0), Vector3(0.72, 0.72, 0.72), fruit_material)
	_add_cylinder_mesh(fruit_visuals, "Stem", Vector3(0.0, 1.28, 0.0), Vector3(0.12, 0.28, 0.12), _material(Color(0.3, 0.23, 0.1)))
	_add_sphere_mesh(fruit_visuals, "Leaf", Vector3(0.25, 1.36, 0.0), Vector3(0.36, 0.1, 0.18), _material(Color(0.31, 0.56, 0.21)))
	fruit.set_visual_root(fruit_visuals)
	var fruit_collision := CollisionShape3D.new()
	var fruit_shape := SphereShape3D.new()
	fruit_shape.radius = 0.72
	fruit_collision.shape = fruit_shape
	fruit_collision.position.y = 0.72
	fruit.set_collision(fruit_collision)
	add_child(fruit)
	objects["fruit"] = fruit
	_add_label("Honey fruit", fruit.global_position + Vector3(0.0, 1.9, 0.0), 20, Color(1.0, 0.83, 0.48))

	var spinner := Interactable.new()
	spinner.name = "WindUpSpinner"
	spinner.configure("spinner", "toy", "Wind-up spinner", ["play"])
	spinner.position = Vector3(42.0, 0.0, -2.4)
	spinner.collision_layer = 2
	spinner.collision_mask = 0
	var spinner_visuals := Node3D.new()
	_add_cylinder_mesh(spinner_visuals, "Base", Vector3(0.0, 0.2, 0.0), Vector3(0.72, 0.35, 0.72), _material(Color(0.29, 0.42, 0.63)))
	_add_cylinder_mesh(spinner_visuals, "Axle", Vector3(0.0, 0.56, 0.0), Vector3(0.12, 0.42, 0.12), _material(Color(0.85, 0.72, 0.35)))
	_add_sphere_mesh(spinner_visuals, "Center", Vector3(0.0, 0.82, 0.0), Vector3(0.35, 0.24, 0.35), _material(Color(0.95, 0.62, 0.2)))
	_add_box_mesh(spinner_visuals, "ArmA", Vector3(0.0, 0.82, 0.0), Vector3(1.65, 0.12, 0.18), _material(Color(0.76, 0.3, 0.3)))
	_add_box_mesh(spinner_visuals, "ArmB", Vector3(0.0, 0.82, 0.0), Vector3(0.18, 0.12, 1.65), _material(Color(0.3, 0.7, 0.54)))
	spinner.set_visual_root(spinner_visuals)
	var spinner_collision := CollisionShape3D.new()
	var spinner_shape := CylinderShape3D.new()
	spinner_shape.radius = 0.75
	spinner_shape.height = 1.0
	spinner_collision.shape = spinner_shape
	spinner_collision.position.y = 0.5
	spinner.set_collision(spinner_collision)
	add_child(spinner)
	objects["spinner"] = spinner
	_add_label("Wind-up spinner", spinner.global_position + Vector3(0.0, 1.55, 0.0), 20, Color(0.72, 0.87, 1.0))
	_build_drawing_station()


func _build_drawing_station() -> void:
	var surface := Interactable.new()
	surface.name = "DrawingSurface"
	surface.configure(DRAWING_SURFACE_ID, "surface", "Marking board", ["draw"])
	surface.position = Vector3(4.0, 0.0, -5.6)
	surface.collision_layer = 2
	surface.collision_mask = 0
	var visuals := Node3D.new()
	visuals.name = "DrawingStationVisuals"
	_add_box_mesh(visuals, "WoodenFrame", Vector3(0.0, 1.58, -0.055), Vector3(2.5, 1.75, 0.16), _material(Color(0.48, 0.31, 0.18)))
	_drawing_panel = MeshInstance3D.new()
	_drawing_panel.name = "MarkingPanel"
	var panel_mesh := QuadMesh.new()
	panel_mesh.size = Vector2(DRAWING_SURFACE_WIDTH, DRAWING_SURFACE_HEIGHT)
	_drawing_panel.mesh = panel_mesh
	_drawing_panel.position = Vector3(0.0, 1.58, 0.035)
	var panel_material := StandardMaterial3D.new()
	panel_material.albedo_texture = drawing_surface.get("texture") as Texture2D
	panel_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	panel_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	panel_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_drawing_panel.material_override = panel_material
	visuals.add_child(_drawing_panel)
	_add_box_mesh(visuals, "LowerShelf", Vector3(0.0, 0.62, 0.14), Vector3(2.65, 0.12, 0.45), _material(Color(0.42, 0.28, 0.16)))
	surface.set_visual_root(visuals)
	var surface_collision := CollisionShape3D.new()
	var surface_shape := BoxShape3D.new()
	surface_shape.size = Vector3(2.55, 2.25, 0.3)
	surface_collision.shape = surface_shape
	surface_collision.position.y = 1.28
	surface.set_collision(surface_collision)
	add_child(surface)
	objects[DRAWING_SURFACE_ID] = surface
	_add_label("Marking board", surface.position + Vector3(-0.8, 2.72, 0.0), 18, Color(0.96, 0.88, 0.7))

	var charcoal := Interactable.new()
	charcoal.name = "CharcoalTool"
	charcoal.configure(DRAWING_TOOL_ID, "tool", "Charcoal", ["draw"])
	charcoal.position = surface.position + Vector3(-1.02, 0.0, 0.34)
	charcoal.collision_layer = 2
	charcoal.collision_mask = 0
	var charcoal_visuals := Node3D.new()
	_add_box_mesh(charcoal_visuals, "ToolRest", Vector3(0.0, 0.3, 0.0), Vector3(0.62, 0.12, 0.42), _material(Color(0.57, 0.4, 0.23)))
	var stick := MeshInstance3D.new()
	stick.name = "CharcoalStick"
	var stick_mesh := CylinderMesh.new()
	stick_mesh.top_radius = 0.045
	stick_mesh.bottom_radius = 0.045
	stick_mesh.height = 0.54
	stick_mesh.radial_segments = 8
	stick.mesh = stick_mesh
	stick.position = Vector3(0.0, 0.44, 0.0)
	stick.rotation.z = PI * 0.5
	stick.material_override = _material(Color(0.09, 0.075, 0.065))
	charcoal_visuals.add_child(stick)
	charcoal.set_visual_root(charcoal_visuals)
	var charcoal_collision := CollisionShape3D.new()
	var charcoal_shape := SphereShape3D.new()
	charcoal_shape.radius = 0.34
	charcoal_collision.shape = charcoal_shape
	charcoal_collision.position.y = 0.4
	charcoal.set_collision(charcoal_collision)
	add_child(charcoal)
	objects[DRAWING_TOOL_ID] = charcoal
	_add_label("Charcoal", charcoal.position + Vector3(-0.1, 0.85, 0.0), 14, Color(0.88, 0.82, 0.72))
	_build_expanded_habitat_objects()


func _build_expanded_habitat_objects() -> void:
	var berry_bush := Interactable.new()
	berry_bush.name = "BerryBush"
	berry_bush.configure("berry_bush", "resource", "Berry bush", ["forage"])
	berry_bush.position = Vector3(28.0, 0.0, 3.0)
	berry_bush.collision_layer = 2
	berry_bush.collision_mask = 0
	var bush_visuals := Node3D.new()
	_add_cylinder_mesh(bush_visuals, "BerryBushStem", Vector3(0.0, 0.48, 0.0), Vector3(0.22, 0.96, 0.22), _material(Color(0.28, 0.22, 0.13)))
	_add_sphere_mesh(bush_visuals, "BerryBushCrownA", Vector3(-0.43, 0.95, 0.0), Vector3(0.62, 0.48, 0.54), _material(Color(0.22, 0.43, 0.25)))
	_add_sphere_mesh(bush_visuals, "BerryBushCrownB", Vector3(0.38, 0.92, 0.0), Vector3(0.63, 0.51, 0.56), _material(Color(0.28, 0.49, 0.27)))
	_add_sphere_mesh(bush_visuals, "BerryBushCrownTop", Vector3(0.0, 1.35, 0.0), Vector3(0.55, 0.49, 0.5), _material(Color(0.24, 0.45, 0.24)))
	for berry_index: int in range(7):
		var angle := TAU * float(berry_index) / 7.0
		var berry_position := Vector3(cos(angle) * 0.53, 0.85 + float(berry_index % 3) * 0.22, sin(angle) * 0.44)
		_add_sphere_mesh(bush_visuals, "Berry%d" % berry_index, berry_position, Vector3.ONE * 0.14, _material(Color(0.62, 0.16, 0.3)))
	berry_bush.set_visual_root(bush_visuals)
	var berry_collision := CollisionShape3D.new()
	var berry_shape := SphereShape3D.new()
	berry_shape.radius = 0.38
	berry_collision.shape = berry_shape
	berry_collision.position.y = 0.52
	berry_bush.set_collision(berry_collision)
	add_child(berry_bush)
	objects["berry_bush"] = berry_bush
	_add_label("Berry bush", berry_bush.position + Vector3(0.0, 1.95, 0.0), 19, Color(1.0, 0.77, 0.86))

	var spring := Interactable.new()
	spring.name = "GlassfallSpring"
	spring.configure("spring", "resource", "Glassfall spring", ["drink"])
	spring.position = Vector3(50.0, 0.0, 3.0)
	spring.collision_layer = 2
	spring.collision_mask = 0
	var spring_visuals := Node3D.new()
	var water := MeshInstance3D.new()
	water.name = "SpringWater"
	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = 0.82
	water_mesh.bottom_radius = 0.82
	water_mesh.height = 0.12
	water.mesh = water_mesh
	water.position.y = 0.18
	water.material_override = _material(Color(0.22, 0.72, 0.82, 0.88))
	spring_visuals.add_child(water)
	var spring_rim := MeshInstance3D.new()
	spring_rim.name = "SpringStoneRim"
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = 0.68
	rim_mesh.outer_radius = 0.93
	spring_rim.mesh = rim_mesh
	spring_rim.position.y = 0.12
	spring_rim.material_override = _material(Color(0.56, 0.65, 0.62))
	spring_visuals.add_child(spring_rim)
	for shard_index: int in range(5):
		var angle := TAU * float(shard_index) / 5.0
		var shard_position := Vector3(cos(angle) * 0.72, 0.18, sin(angle) * 0.72)
		_add_sphere_mesh(spring_visuals, "SpringGlass%d" % shard_index, shard_position, Vector3(0.17, 0.2, 0.14), _material(Color(0.63, 0.87, 0.9)))
	spring.set_visual_root(spring_visuals)
	var spring_collision := CollisionShape3D.new()
	var spring_shape := SphereShape3D.new()
	spring_shape.radius = 0.36
	spring_collision.shape = spring_shape
	spring_collision.position.y = 0.32
	spring.set_collision(spring_collision)
	add_child(spring)
	objects["spring"] = spring
	_add_label("Glassfall spring", spring.position + Vector3(0.0, 1.25, 0.0), 19, Color(0.73, 0.92, 1.0))

	var echo_bloom := Interactable.new()
	echo_bloom.name = "EchoBloom"
	echo_bloom.configure("echo_bloom", "landmark", "Echo bloom", ["explore"])
	echo_bloom.position = Vector3(56.5, 0.0, -3.0)
	echo_bloom.collision_layer = 2
	echo_bloom.collision_mask = 0
	var bloom_visuals := Node3D.new()
	_add_cylinder_mesh(bloom_visuals, "EchoBloomStem", Vector3(0.0, 0.72, 0.0), Vector3(0.16, 1.44, 0.16), _material(Color(0.3, 0.51, 0.37)))
	for petal_index: int in range(6):
		var angle := TAU * float(petal_index) / 6.0
		var petal_position := Vector3(cos(angle) * 0.55, 1.55 + float(petal_index % 2) * 0.14, sin(angle) * 0.55)
		var petal := _material(Color(0.53, 0.86, 0.76) if petal_index % 2 == 0 else Color(0.85, 0.78, 0.48))
		_add_sphere_mesh(bloom_visuals, "EchoPetal%d" % petal_index, petal_position, Vector3(0.4, 0.18, 0.25), petal)
	_add_sphere_mesh(bloom_visuals, "EchoBloomHeart", Vector3(0.0, 1.58, 0.0), Vector3(0.34, 0.3, 0.34), _material(Color(0.98, 0.83, 0.42)))
	echo_bloom.set_visual_root(bloom_visuals)
	var bloom_collision := CollisionShape3D.new()
	var bloom_shape := SphereShape3D.new()
	bloom_shape.radius = 0.35
	bloom_collision.shape = bloom_shape
	bloom_collision.position.y = 0.8
	echo_bloom.set_collision(bloom_collision)
	add_child(echo_bloom)
	objects["echo_bloom"] = echo_bloom
	_add_label("Echo bloom", echo_bloom.position + Vector3(0.0, 2.2, 0.0), 19, Color(0.8, 1.0, 0.84))

	var marker_positions: Array[float] = [10.0, 17.0, 24.0, 31.0, 38.0, 45.0, 52.0, 59.0]
	for marker_index: int in range(marker_positions.size()):
		var marker_id := "route_marker_%d" % (marker_index + 1)
		var marker := Interactable.new()
		marker.name = "CuriosityMarker%d" % (marker_index + 1)
		marker.configure(marker_id, "landmark", "Curiosity marker", ["explore"])
		marker.position = Vector3(marker_positions[marker_index], 0.0, 0.0)
		marker.collision_layer = 2
		marker.collision_mask = 0
		var marker_visuals := Node3D.new()
		_add_sphere_mesh(marker_visuals, "MarkerGlow", Vector3(0.0, 0.48, 0.0), Vector3(0.42, 0.3, 0.42), _material(Color(0.74, 0.81, 0.48)))
		_add_sphere_mesh(marker_visuals, "MarkerCore", Vector3(0.0, 0.44, 0.0), Vector3(0.18, 0.2, 0.18), _material(Color(0.99, 0.89, 0.56)))
		marker.set_visual_root(marker_visuals)
		var marker_collision := CollisionShape3D.new()
		var marker_shape := SphereShape3D.new()
		marker_shape.radius = 0.24
		marker_collision.shape = marker_shape
		marker_collision.position.y = 0.42
		marker.set_collision(marker_collision)
		add_child(marker)
		objects[marker_id] = marker


func _step_profile_chemistry(profile: NornProfile) -> void:
	if profile == null or profile.actor == null:
		return
	var chemistry_signals: Dictionary = Biochemistry.advance_and_read_signals(profile.biochemistry_state, {
		"active": 1.0 if profile.actor.is_walking else 0.0,
		"resting": 1.0 if profile.actor.current_action == "rest" else 0.0,
		"nearbyPeer": 1.0 if not _sense_peers(profile).is_empty() else 0.0
	}, CHEMISTRY_STEP)
	if not chemistry_signals.is_empty():
		Cognition.sync_chemistry(profile.cognition_state, chemistry_signals)
		if profile.actor_id == "mallow":
			_sync_mallow_compatibility()


func _sense_peers(profile: NornProfile) -> Array[Dictionary]:
	var sensed: Array[Dictionary] = []
	if profile == null or profile.actor == null or not profile.actor.is_inside_tree():
		return sensed
	for other: NornProfile in norn_profiles.values():
		if other == profile or other.actor == null or not other.actor.is_inside_tree():
			continue
		var distance := profile.actor.global_position.distance_to(other.actor.global_position)
		if distance <= SENSE_RADIUS and profile.actor.can_see_peer(other.actor):
			sensed.append({"id": other.actor_id, "name": other.display_name, "distance": distance})
	sensed.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return float(left["distance"]) < float(right["distance"]))
	return sensed


func _nearest_living_parent(profile: NornProfile) -> NornProfile:
	if profile == null or profile.actor == null:
		return null
	var nearest: NornProfile
	var nearest_distance := INF
	for parent_id: String in profile.parent_ids:
		var parent := profile_for(parent_id)
		if parent == null or parent == profile or not bool(parent.life_state.get("alive", false)) or parent.actor == null or not is_instance_valid(parent.actor) or not parent.actor.is_inside_tree():
			continue
		var distance := profile.actor.global_position.distance_to(parent.actor.global_position)
		if distance < nearest_distance:
			nearest = parent
			nearest_distance = distance
	return nearest


func _nearest_visible_parent(profile: NornProfile, nearby_norns: Array[Dictionary]) -> NornProfile:
	if profile == null:
		return null
	for peer: Dictionary in nearby_norns:
		var parent_id := str(peer.get("id", ""))
		if not profile.parent_ids.has(parent_id):
			continue
		var parent := profile_for(parent_id)
		if parent != null and bool(parent.life_state.get("alive", false)) and parent.actor != null and is_instance_valid(parent.actor) and parent.actor.is_inside_tree():
			return parent
	return null


func _sense_objects(profile: NornProfile) -> Array[Dictionary]:
	var sensed: Array[Dictionary] = []
	if profile == null or profile.actor == null or not profile.actor.is_inside_tree():
		return sensed
	for item: Interactable in objects.values():
		if not item.available:
			continue
		if _is_exploration_landmark_id(item.object_id) and profile.explored_landmarks.has(item.object_id):
			continue
		var distance := profile.actor.global_position.distance_to(item.global_position)
		if distance > SENSE_RADIUS or not profile.actor.can_see_interactable(item):
			continue
		sensed.append({
			"id": item.object_id,
			"kind": item.kind,
			"label": item.display_name,
			"distance": distance * 90.0,
			"affordances": item.affordances.duplicate()
		})
	sensed.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return float(left["distance"]) < float(right["distance"]))
	return sensed


func _sensed_object_exists(sensed: Array[Dictionary], object_id: String) -> bool:
	for entry: Dictionary in sensed:
		if str(entry.get("id", "")) == object_id and bool(entry.get("available", true)):
			return true
	return false


func _action_target_id(action_id: String) -> String:
	match action_id:
		"fruit", "spinner":
			return action_id
		"forage":
			return "berry_bush"
		"drink":
			return "spring"
	return ""


func _action_for_target(target_id: String) -> String:
	match target_id:
		"fruit":
			return "fruit"
		"spinner":
			return "spinner"
		"berry_bush":
			return "forage"
		"spring":
			return "drink"
		"drawing_surface", "charcoal":
			return "draw"
		_:
			return "explore" if target_id == "echo_bloom" or target_id.begins_with("route_marker_") else "idle"


func _nearest_sensed_target_with_affordance(sensed: Array[Dictionary], affordance: String) -> String:
	for entry: Dictionary in sensed:
		var affordances: Variant = entry.get("affordances", [])
		var object_id := str(entry.get("id", ""))
		if affordances is Array and affordances.has(affordance) and objects.has(object_id):
			return object_id
	return ""


func _run_decision(profile: NornProfile) -> void:
	if profile == null or profile.cognition_state.is_empty() or profile.actor == null:
		return
	var nearby_objects := _sense_objects(profile)
	var nearby_norns := _sense_peers(profile)
	var surface_marks := PackedFloat32Array()
	if drawing_surface != null and _sensed_object_exists(nearby_objects, DRAWING_SURFACE_ID):
		var cursor_uv: Vector2 = drawing_surface.call("get_last_uv", profile.actor_id)
		surface_marks = drawing_surface.call("sample_mark_grid", cursor_uv, 16)
	var active_guidance: Variant = null
	if not profile.guidance.is_empty():
		var guided_target_id := str(profile.guidance.get("objectId", ""))
		if objects.has(guided_target_id) and (objects[guided_target_id] as Interactable).available:
			active_guidance = profile.guidance
		else:
			profile.guidance.clear()
	var observation := {
		"time": simulation_time,
		"chemistry": profile.cognition_state["chemistry"],
		"nearbyObjects": nearby_objects,
		"nearbyNorns": nearby_norns,
		"surfaceMarks": surface_marks,
		"guidance": active_guidance,
		"languageSignals": {}
	}
	var decision: Dictionary = Cognition.decide(profile.cognition_state, observation)
	profile.recalled_moments.clear()
	var episodes_by_id: Dictionary = {}
	for episode_value: Variant in profile.cognition_state["episodes"]:
		if episode_value is Dictionary:
			var episode: Dictionary = episode_value
			episodes_by_id[int(episode.get("id", -1))] = episode
	var recalled_episode_ids: Array = decision.get("recalledEpisodeIds", [])
	for episode_id_value: Variant in recalled_episode_ids:
		var recalled_episode: Variant = episodes_by_id.get(int(episode_id_value), null)
		if recalled_episode is Dictionary:
			profile.recalled_moments.append((recalled_episode as Dictionary).duplicate(true))
	var effective_action := str(decision.get("actionId", "idle"))
	var reason := str(decision.get("reason", "Looking around the habitat"))
	var target: Node3D
	var target_id := ""
	if active_guidance is Dictionary and objects.has(active_guidance.get("objectId", "")):
		target_id = str(active_guidance["objectId"])
		var guided_item: Interactable = objects[target_id]
		if guided_item.available:
			effective_action = _action_for_target(target_id)
			target = guided_item
			reason = "Following your guidance to %s" % guided_item.display_name.to_lower()
		else:
			effective_action = "idle"
			target_id = ""
	elif ["fruit", "spinner", "forage", "drink"].has(effective_action):
		var action_target_id := _action_target_id(effective_action)
		var item_value: Variant = objects.get(action_target_id, null)
		if item_value is Interactable:
			var item: Interactable = item_value
			if item.available and nearby_objects.any(func(entry: Dictionary) -> bool: return entry["id"] == action_target_id):
				target = item
				target_id = action_target_id
	elif effective_action == "explore":
		var exploration_target_id := _nearest_sensed_target_with_affordance(nearby_objects, "explore")
		var exploration_target: Variant = objects.get(exploration_target_id, null)
		if exploration_target is Interactable:
			target = exploration_target
			target_id = exploration_target_id
			reason = "Following a local curiosity cue"
	elif effective_action == "draw" and objects.has(DRAWING_SURFACE_ID) and objects.has(DRAWING_TOOL_ID):
		var surface_item: Interactable = objects[DRAWING_SURFACE_ID]
		var charcoal_item: Interactable = objects[DRAWING_TOOL_ID]
		if surface_item.available and charcoal_item.available and _sensed_object_exists(nearby_objects, DRAWING_SURFACE_ID) and _sensed_object_exists(nearby_objects, DRAWING_TOOL_ID):
			target = surface_item
			target_id = DRAWING_SURFACE_ID
			if profile.actor.global_position.distance_to(surface_item.global_position) <= NornActor.ARRIVAL_DISTANCE:
				reason = "Making a short exploratory mark"
				_execute_draw_step(profile, decision.get("drawMotorCommand", {}))
			else:
				reason = "Approaching the marking board"
				profile.actor.set_drawing_effector_pose(Vector3.ZERO, false)
		else:
			effective_action = "idle"
			reason = "Looking around the habitat"
	elif effective_action == "observe_peer" and not nearby_norns.is_empty():
		var peer: NornProfile
		var peer_selection: Dictionary = {}
		if profile.life_stage == "child":
			peer = _nearest_visible_parent(profile, nearby_norns)
		elif profile.life_stage == "adolescent":
			peer_selection = Cognition.select_observation_peer(profile.cognition_state, nearby_norns, profile.parent_ids, profile.life_stage, simulation_time)
			if not peer_selection.is_empty():
				decision["peerSelection"] = peer_selection.duplicate(true)
				peer = profile_for(str(peer_selection.get("peerId", "")))
		if peer == null:
			peer = profile_for(str(nearby_norns[0]["id"]))
		if peer != null:
			if profile.life_stage == "adolescent":
				match str(peer_selection.get("reasonKey", "proximity")):
					"positive_memory":
						reason = "Remembering positive experiences with %s" % peer.display_name
					"negative_memory":
						var avoided_peer := profile_for(str(peer_selection.get("reasonPeerId", "")))
						reason = "Avoiding a negative experience with %s; staying near %s" % [avoided_peer.display_name if avoided_peer != null else "a peer", peer.display_name]
					"adolescent_preference":
						reason = "Observing peer %s beyond the family" % peer.display_name
					_:
						reason = "Observing nearby peer %s" % peer.display_name
			if profile.actor.global_position.distance_to(peer.actor.global_position) > NornActor.OBSERVATION_STOP_DISTANCE:
				target = peer.actor
				target_id = peer.actor_id
	if profile.life_stage == "baby" and active_guidance == null and not ["fruit", "spinner", "forage", "drink", "rest"].has(effective_action):
		var parent := _nearest_living_parent(profile)
		if parent != null:
			effective_action = "observe_peer"
			reason = "Following their parent, %s" % parent.display_name
			if profile.actor.global_position.distance_to(parent.actor.global_position) > NornActor.OBSERVATION_STOP_DISTANCE:
				target = parent.actor
				target_id = parent.actor_id
			else:
				target = null
				target_id = ""
	profile.actor.set_action_target(target, effective_action, reason, target_id)
	profile.current_decision = decision.duplicate(true)
	profile.current_decision["actionId"] = effective_action
	profile.current_decision["reason"] = reason
	if profile.actor_id == "mallow":
		_sync_mallow_compatibility()


func _execute_draw_step(profile: NornProfile, motor_command: Variant) -> bool:
	if profile == null or profile.actor == null or drawing_surface == null or not (motor_command is Dictionary):
		return false
	var command: Dictionary = motor_command
	for field: String in ["dx", "dy", "pressure"]:
		if not _is_finite_number(command.get(field, null)):
			return false
	if not (command.get("contact", null) is bool):
		return false
	var surface_item_value: Variant = objects.get(DRAWING_SURFACE_ID, null)
	var tool_item_value: Variant = objects.get(DRAWING_TOOL_ID, null)
	if not (surface_item_value is Interactable) or not (tool_item_value is Interactable):
		return false
	var surface_item: Interactable = surface_item_value
	var tool_item: Interactable = tool_item_value
	if not surface_item.available or not tool_item.available or profile.actor.global_position.distance_to(surface_item.global_position) > NornActor.ARRIVAL_DISTANCE:
		return false
	var cursor_uv: Vector2 = drawing_surface.call("get_last_uv", profile.actor_id)
	var next_uv := Vector2(
		clampf(cursor_uv.x + clampf(float(command["dx"]), -0.08, 0.08), 0.03, 0.97),
		clampf(cursor_uv.y + clampf(float(command["dy"]), -0.08, 0.08), 0.03, 0.97)
	)
	var pressure := clampf(float(command["pressure"]), 0.05, 0.85)
	var contact := bool(command["contact"])
	if not bool(drawing_surface.call("append_point", profile.actor_id, next_uv, pressure, contact)):
		return false
	if contact:
		profile.actor.set_drawing_effector_pose(_drawing_surface_world_point(next_uv), true)
	else:
		profile.actor.set_drawing_effector_pose(Vector3.ZERO, false)
	var completed_value: Variant = drawing_surface.call("pop_completed_stroke", profile.actor_id)
	if completed_value is Dictionary and not (completed_value as Dictionary).is_empty():
		_record_draw_outcome(profile, completed_value)
	return true


func _drawing_surface_world_point(uv: Vector2) -> Vector3:
	var surface_value: Variant = objects.get(DRAWING_SURFACE_ID, null)
	if not (surface_value is Node3D):
		return Vector3.ZERO
	var local_position := Vector3(
		(uv.x - 0.5) * DRAWING_SURFACE_WIDTH,
		1.58 + (0.5 - uv.y) * DRAWING_SURFACE_HEIGHT,
		0.12
	)
	return (surface_value as Node3D).to_global(local_position)


func _record_draw_outcome(profile: NornProfile, stroke: Dictionary) -> void:
	var points_value: Variant = stroke.get("points", null)
	if not (points_value is Array) or (points_value as Array).is_empty():
		return
	var points: Array = points_value
	var outcome := {
		"eventType": "draw-mark",
		"actionId": "draw",
		"targetId": DRAWING_SURFACE_ID,
		"actorId": profile.actor_id,
		"surfaceId": DRAWING_SURFACE_ID,
		"toolId": DRAWING_TOOL_ID,
		"time": simulation_time,
		"learningDelta": 0.0,
		"reward": 0.0,
		"salience": 0.25,
		"strokeData": {
			"pointCount": points.size(),
			"start": (points[0] as Dictionary).duplicate(true),
			"end": (points[points.size() - 1] as Dictionary).duplicate(true)
		},
		"text": "%s made a short mark on the board." % profile.display_name
	}
	var result: Dictionary = Cognition.record_outcome(profile.cognition_state, outcome)
	if result.is_empty():
		return
	last_status = str(outcome["text"])


func _on_action_completed(actor_id: String, action_id: String, target_id: String) -> void:
	var profile := profile_for(actor_id)
	if profile == null or not objects.has(target_id) or not _is_valid_feedback_pair(action_id, target_id):
		return
	var item: Interactable = objects[target_id]
	if not item.available:
		return
	if profile.actor != null:
		profile.actor.play_interaction_animation(action_id, item.global_position)
	var single_use_landmark := action_id == "explore" and _is_exploration_landmark_id(target_id)
	if str(profile.guidance.get("objectId", "")) == target_id:
		profile.guidance.clear()
	if single_use_landmark and profile.explored_landmarks.has(target_id):
		return
	var event_type := str({"fruit": "food", "spinner": "toy", "forage": "forage", "drink": "drink", "explore": "explore"}.get(action_id, ""))
	var actor_name := profile.display_name
	var outcome_text := "%s ate honey fruit" % actor_name
	match event_type:
		"toy":
			outcome_text = "%s played with the spinner" % actor_name
		"forage":
			outcome_text = "%s foraged berries" % actor_name
		"drink":
			outcome_text = "%s drank from the spring" % actor_name
		"explore":
			outcome_text = "%s explored %s" % [actor_name, item.display_name.to_lower()]
	if single_use_landmark:
		profile.explored_landmarks[target_id] = true
	else:
		item.activate()
		_respawn_times[target_id] = simulation_time + (12.0 if event_type == "forage" else 6.0 if event_type == "drink" else 4.0 if event_type == "toy" else 6.0)
	var spoken_word: Dictionary = _language.call("word_for_target", profile.language_state, target_id)
	var outcome := {
		"eventType": event_type,
		"actionId": action_id,
		"targetId": target_id,
		"actorId": actor_id,
		"time": simulation_time,
		"text": outcome_text
	}
	if not spoken_word.is_empty():
		outcome["word"] = str(spoken_word["word"])
		outcome["text"] += " and said “%s”." % str(spoken_word["word"])
	var result: Dictionary = _apply_profile_biochemistry_event(profile, event_type, outcome)
	outcome["eventId"] = int(result.get("episodeId", 0))
	profile.feedback_action = action_id
	profile.feedback_target = target_id
	profile.feedback_time = simulation_time
	profile.feedback_available = true
	_offer_observation(profile, outcome)
	last_status = "%s. Learned association: %s %.2f (Δ %.2f)." % [
		outcome_text,
		action_id,
		float(result.get("association", 0.0)),
		float(result.get("learningDelta", 0.0))
	]
	if not spoken_word.is_empty():
		last_status += " %s said “%s”." % [actor_name, str(spoken_word["word"])]
	_sync_mallow_compatibility()
	for current_profile: NornProfile in norn_profiles.values():
		_run_decision(current_profile)


func _offer_observation(source: NornProfile, outcome: Dictionary) -> void:
	if source == null:
		return
	var source_event := str(outcome.get("eventType", ""))
	var feedback_event := ["praise", "scold"].has(source_event)
	if not feedback_event and not ["food", "toy", "forage", "drink", "explore"].has(source_event):
		return
	var action_id := str(outcome.get("actionId", ""))
	if not ["fruit", "spinner", "forage", "drink", "explore"].has(action_id):
		return
	for observer: NornProfile in norn_profiles.values():
		if observer == source or not _is_attending(observer, source):
			continue
		var observed_event := "observe-feedback" if feedback_event else "observe"
		var observed := {
			"eventType": observed_event,
			"actorId": source.actor_id,
			"actionId": action_id,
			"targetId": str(outcome.get("targetId", action_id)),
			"feedback": str(outcome.get("feedback", source_event if feedback_event else "")),
			"time": maxf(0.0, float(outcome.get("time", simulation_time))),
			"peerCount": _sense_peers(observer).size(),
			"sociability": float(observer.cognition_state["traits"].get("sociability", 0.5)),
			"learningMultiplier": 1.5 if observer.life_stage == "child" else 1.0,
			"eventId": int(outcome.get("eventId", 0)),
			"text": "%s observed %s %s" % [observer.display_name, source.display_name, action_id]
		}
		if feedback_event:
			observed["text"] += " and was %s" % observed["feedback"]
		var before: Dictionary = Biochemistry.read_signals(observer.biochemistry_state)
		if Biochemistry.apply_event(observer.biochemistry_state, "social").is_empty():
			continue
		var after: Dictionary = Biochemistry.read_signals(observer.biochemistry_state)
		if not Cognition.sync_chemistry(observer.cognition_state, after):
			continue
		Cognition.record_outcome(observer.cognition_state, observed, {"before": before, "after": after})
		if observer.actor_id == "mallow":
			_sync_mallow_compatibility()


func _is_attending(observer: NornProfile, source: NornProfile) -> bool:
	if observer == null or source == null or observer.actor == null or source.actor == null:
		return false
	if not observer.actor.is_inside_tree() or not source.actor.is_inside_tree():
		return false
	if observer.actor.current_action != "observe_peer" or observer.actor.is_walking or observer.actor.target != null:
		return false
	if observer.actor.global_position.distance_to(source.actor.global_position) > OBSERVATION_RADIUS:
		return false
	return observer.actor.can_see_peer(source.actor)


func _update_timed_state() -> void:
	for profile: NornProfile in norn_profiles.values():
		if not profile.guidance.is_empty():
			var target_id := str(profile.guidance.get("objectId", ""))
			if not objects.has(target_id) or not (objects[target_id] as Interactable).available:
				profile.guidance.clear()
		if profile.feedback_available and simulation_time - profile.feedback_time > FEEDBACK_WINDOW:
			profile.feedback_available = false
	for object_id: String in _respawn_times.keys():
		if simulation_time >= float(_respawn_times[object_id]):
			(objects[object_id] as Interactable).set_available(true)
			_respawn_times.erase(object_id)
	_sync_mallow_compatibility()


func _fallback_from_invalid_save(reason: String) -> void:
	_reset_state(false)
	last_status = "%s; started a clean seeded Norn." % reason
	_refresh_ui()


func _reset_state(write_save: bool) -> void:
	teaching_mode = false
	if _ui != null:
		_ui.clear_teaching_input()
	if drawing_surface == null:
		drawing_surface = DrawingSurfaceScript.new() as RefCounted
	var empty_surface: Dictionary = DrawingSurfaceScript.new().call("serialize_state")
	drawing_surface.call("restore_state", empty_surface)
	simulation_time = 0.0
	_chemistry_accumulator = 0.0
	_decision_accumulator = 0.0
	_respawn_times.clear()
	for item: Interactable in objects.values():
		item.set_available(true)
	_create_profiles()
	if write_save:
		save_game()


func _refresh_ui() -> void:
	if _ui == null:
		return
	var profile := focused_profile()
	if profile != null and (not bool(profile.life_state.get("alive", false)) or profile.actor == null):
		profile = null
	var roster: Array[Dictionary] = []
	for living: NornProfile in living_profiles():
		roster.append({
			"actorId": living.actor_id,
			"displayName": living.display_name,
			"ageSeconds": float(living.life_state.get("ageSeconds", 0.0)),
			"lifeStage": living.life_stage,
			"generation": living.generation,
			"parentIds": living.parent_ids.duplicate()
		})
	var archived_norns: Array[Dictionary] = []
	for actor_id: String in ordered_profile_ids():
		var archived := profile_for(actor_id)
		if archived == null or bool(archived.life_state.get("alive", false)):
			continue
		var death: Dictionary = archived.life_state.get("death", {})
		archived_norns.append({
			"actorId": archived.actor_id,
			"displayName": archived.display_name,
			"ageSeconds": float(archived.life_state.get("ageSeconds", 0.0)),
			"lifeStage": archived.life_stage,
			"generation": archived.generation,
			"parentIds": archived.parent_ids.duplicate(),
			"cause": str(death.get("cause", "old-age"))
		})
	var egg_records: Array[Dictionary] = []
	for egg_record: Dictionary in eggs:
		egg_records.append(egg_record.duplicate(true))
	var chemistry: Dictionary = profile.cognition_state.get("chemistry", {}) if profile != null else {}
	var compounds: Dictionary = Biochemistry.read_compounds(profile.biochemistry_state) if profile != null else {}
	var reaction_fluxes: Dictionary = Biochemistry.read_fluxes(profile.biochemistry_state) if profile != null else {}
	var roster_is_empty := roster.is_empty()
	_ui.update_view({
		"actorId": profile.actor_id if profile != null else "",
		"displayName": profile.display_name if profile != null else "",
		"chemistry": chemistry,
		"decision": profile.current_decision if profile != null else {},
		"recalled": profile.recalled_moments if profile != null else [],
		"languageState": profile.language_state if profile != null else {},
		"compounds": compounds,
		"reactionFluxes": reaction_fluxes,
		"ageSeconds": float(profile.life_state.get("ageSeconds", 0.0)) if profile != null else -1.0,
		"lifeStage": profile.life_stage if profile != null else "none",
		"roster": roster,
		"eggRecords": egg_records,
		"archivedNorns": archived_norns,
		"populationCount": population_count(),
		"eggsOnly": roster_is_empty and not egg_records.is_empty(),
		"extinct": roster_is_empty and egg_records.is_empty(),
		"status": last_status,
		"paused": paused,
		"speed": simulation_speed,
		"feedbackReady": profile != null and profile.feedback_available and simulation_time - profile.feedback_time <= FEEDBACK_WINDOW,
		"recording": video_recorder != null and video_recorder.is_recording(),
		"recordingElapsed": video_recorder.recording_time() if video_recorder != null else 0.0,
		"lastRecordingPath": last_recording_path,
		"recordingError": video_recorder.last_error if video_recorder != null else "",
		"recordedFrameCount": recorded_frame_count,
		"teachingMode": teaching_mode,
		"drawingStrokeCount": drawing_surface.call("get_stroke_count") if drawing_surface != null else 0,
		"drawingSurfaceTexture": drawing_surface.get("texture") as Texture2D if drawing_surface != null else null
	})


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var step := 0.9
		if event.keycode == KEY_W or event.keycode == KEY_UP:
			_camera_target.z -= step
		elif event.keycode == KEY_S or event.keycode == KEY_DOWN:
			_camera_target.z += step
		elif event.keycode == KEY_A or event.keycode == KEY_LEFT:
			_camera_target.x -= step
		elif event.keycode == KEY_D or event.keycode == KEY_RIGHT:
			_camera_target.x += step
		elif event.keycode == KEY_SPACE:
			toggle_pause()
			return
		else:
			return
		_camera_follow_enabled = false
		_update_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_offset *= 0.9
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_offset *= 1.1
		else:
			return
		_camera_offset = _camera_offset.normalized() * clampf(_camera_offset.length(), 6.0, 24.0)
		_update_camera()


func _update_camera() -> void:
	if _camera == null:
		return
	if _camera_follow_enabled:
		var profile := focused_profile()
		if profile != null and profile.actor != null and is_instance_valid(profile.actor):
			_camera_target = profile.actor.global_position + Vector3(0.0, 0.45, 0.0)
	_camera.global_position = _camera_target + _camera_offset
	_camera.look_at(_camera_target, Vector3.UP)


func _add_path(at: Vector3, size: Vector3) -> void:
	var path := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	path.mesh = box
	path.position = at
	path.material_override = _material(Color(0.56, 0.48, 0.32))
	add_child(path)


func _add_tree(at: Vector3, scale_value: float, leaf_color: Color) -> void:
	var tree := Node3D.new()
	tree.position = at
	_add_cylinder_mesh(tree, "Trunk", Vector3(0.0, 1.0 * scale_value, 0.0), Vector3(0.22 * scale_value, 1.0 * scale_value, 0.22 * scale_value), _material(Color(0.32, 0.22, 0.13)))
	_add_sphere_mesh(tree, "Canopy", Vector3(0.0, 2.2 * scale_value, 0.0), Vector3(1.5 * scale_value, 1.65 * scale_value, 1.25 * scale_value), _material(leaf_color))
	add_child(tree)


func _add_rock(at: Vector3, size: Vector3) -> void:
	var rock := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radial_segments = 9
	sphere.rings = 5
	rock.mesh = sphere
	rock.position = at
	rock.scale = size
	rock.material_override = _material(Color(0.36, 0.39, 0.31))
	add_child(rock)


func _add_label(text_value: String, at: Vector3, font_size: int, color: Color) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = at
	label.font_size = font_size
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	label.outline_modulate = Color(0.1, 0.12, 0.08, 0.95)
	add_child(label)


func _add_sphere_mesh(parent: Node3D, label: String, at: Vector3, size: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	var sphere := SphereMesh.new()
	sphere.radial_segments = 12
	sphere.rings = 7
	mesh_instance.mesh = sphere
	mesh_instance.position = at
	mesh_instance.scale = size
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)


func _add_cylinder_mesh(parent: Node3D, label: String, at: Vector3, size: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.5
	cylinder.bottom_radius = 0.5
	cylinder.height = 1.0
	mesh_instance.mesh = cylinder
	mesh_instance.position = at
	mesh_instance.scale = size
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)


func _add_box_mesh(parent: Node3D, label: String, at: Vector3, size: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = at
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material


func _is_finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
