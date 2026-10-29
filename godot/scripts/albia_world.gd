class_name AlbiaWorld
extends Node3D

const Cognition = preload("res://scripts/norn_cognition.gd")
const Biochemistry = preload("res://scripts/norn_biochemistry.gd")
const HabitatUi = preload("res://scripts/habitat_ui.gd")
const NornLanguageScript = preload("res://scripts/norn_language.gd")
const VideoRecorder = preload("res://scripts/local_video_recorder.gd")
const START_SEED := 4181996
const SAVE_PATH := "user://albia_norn_save.json"
const SAVE_VERSION := 3
const CHEMISTRY_STEP := 0.1
const DECISION_STEP := 0.2
const FEEDBACK_WINDOW := 12.0

var norn: NornActor
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
var _chemistry_accumulator: float = 0.0
var _decision_accumulator: float = 0.0
var _respawn_times: Dictionary = {}


func _ready() -> void:
	_build_environment()
	_build_habitat()
	_build_camera()
	_build_creature()
	_build_objects()
	cognition_state = _new_cognition_state()
	biochemistry_state = Biochemistry.create_state(cognition_state["chemistry"])
	Cognition.sync_chemistry(cognition_state, Biochemistry.read_signals(biochemistry_state))
	_language = NornLanguageScript.new()
	language_state = _language.call("create_state")
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
	simulation_time += step_delta
	_chemistry_accumulator = minf(_chemistry_accumulator + step_delta, CHEMISTRY_STEP * 5.0)
	_decision_accumulator = minf(_decision_accumulator + step_delta, DECISION_STEP * 3.0)
	var chemistry_steps := 0
	while _chemistry_accumulator >= CHEMISTRY_STEP and chemistry_steps < 5:
		var chemistry_signals: Dictionary = Biochemistry.advance_and_read_signals(biochemistry_state, {
			"active": 1.0 if norn != null and norn.is_walking else 0.0,
			"resting": 1.0 if norn != null and norn.current_action == "rest" else 0.0,
			"nearbyPeer": 0.0
		}, CHEMISTRY_STEP)
		if not chemistry_signals.is_empty():
			Cognition.sync_chemistry(cognition_state, chemistry_signals)
		_chemistry_accumulator -= CHEMISTRY_STEP
		chemistry_steps += 1
	var decision_steps := 0
	while _decision_accumulator >= DECISION_STEP and decision_steps < 3:
		_decision_accumulator -= DECISION_STEP
		decision_steps += 1
		_run_decision()
	_update_timed_state()
	_refresh_ui()


func guide_to(object_id: String) -> void:
	if not objects.has(object_id):
		return
	var item: Interactable = objects[object_id]
	if not item.available:
		last_status = "%s is having a short rest." % item.display_name
		_refresh_ui()
		return
	guidance = {"objectId": object_id, "expiresAt": simulation_time + 7.0}
	last_status = "You pointed toward %s." % item.display_name
	_run_decision()
	_refresh_ui()


func give_feedback(feedback: String) -> void:
	if teaching_mode:
		last_status = "Teach mode is on. Choose the word's meaning with the target buttons."
		_refresh_ui()
		return
	if not ["praise", "scold"].has(feedback):
		return
	if not feedback_available or simulation_time - feedback_time > FEEDBACK_WINDOW:
		last_status = "Wait for Mallow to eat or play, then respond within 12 seconds."
		_refresh_ui()
		return
	var feedback_word: Dictionary = _language.call("word_for_target", language_state, feedback)
	var outcome := {
		"eventType": feedback,
		"actionId": feedback_action,
		"targetId": feedback_target if not feedback_target.is_empty() else feedback,
		"actorId": "Mallow",
		"time": simulation_time,
		"text": "You %s Mallow after %s." % [feedback, feedback_action]
	}
	if not feedback_word.is_empty():
		outcome["word"] = str(feedback_word["word"])
	var result: Dictionary = _apply_biochemistry_event(feedback, outcome)
	feedback_available = false
	var amount := float(result.get("learningDelta", 0.0))
	var feedback_result := "praised" if feedback == "praise" else "scolded"
	var language_delta := 0.14 if feedback == "praise" else -0.14
	var adjusted_words: Array = _language.call("adjust_target", language_state, feedback_action, language_delta)
	last_status = "Mallow was %s. %s association %s%.2f." % [
		feedback_result,
		feedback_action.capitalize(),
		"+" if amount >= 0.0 else "",
		amount
	]
	if not adjusted_words.is_empty():
		var changed_word: Dictionary = adjusted_words[0]
		last_status += " %s confidence %.2f." % [str(changed_word["word"]), float(changed_word["confidence"])]
	if not feedback_word.is_empty():
		last_status += " Mallow said “%s”." % str(feedback_word["word"])
	_refresh_ui()


func toggle_teaching_mode() -> void:
	teaching_mode = not teaching_mode
	if teaching_mode:
		last_status = "Teach mode is on. Type one word, then choose fruit, spinner, Praise, or Scold."
	else:
		last_status = "Teach mode cancelled."
		if _ui != null:
			_ui.clear_teaching_input()
	_refresh_ui()


func select_hud_target(target_id: String, input_word: String = "") -> void:
	if teaching_mode:
		teach_word(input_word, target_id)
		return
	if target_id == "fruit" or target_id == "spinner":
		guide_to(target_id)
	elif target_id == "praise" or target_id == "scold":
		give_feedback(target_id)


func teach_word(input_word: String, target_id: String) -> void:
	if not teaching_mode:
		last_status = "Choose Teach word before pairing a word with a target."
		_refresh_ui()
		return
	var result: Dictionary = _language.call("teach_word", language_state, input_word, target_id)
	if not bool(result.get("ok", false)):
		last_status = str(result.get("error", "That word could not be taught."))
		_refresh_ui()
		return
	var word := str(result.get("word", ""))
	var confidence := float(result.get("confidence", 0.0))
	var target_name := _language_target_name(target_id)
	var readiness := " Mallow can now use it." if confidence >= 0.60 else " Teach again or praise correct use to build confidence."
	last_status = "Taught “%s” to %s (%.2f confidence).%s" % [word, target_name, confidence, readiness]
	_apply_biochemistry_event("teach-word", {
		"eventType": "teach-word",
		"targetId": target_id,
		"time": simulation_time,
		"word": word,
		"text": "Mallow learned “%s” for %s." % [word, target_name]
	})
	_refresh_ui()


func _language_target_name(target_id: String) -> String:
	match target_id:
		"fruit":
			return "honey fruit"
		"spinner":
			return "the wind-up spinner"
		"praise":
			return "Praise"
		"scold":
			return "Scold"
	return "that target"


func toggle_pause() -> void:
	paused = not paused
	if norn != null:
		norn.set_physics_process(not paused)
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
	var saved_language: Dictionary = _language.call("serialize_state", language_state)
	if saved_language.is_empty():
		last_status = "The local vocabulary could not be saved because it failed validation."
		_refresh_ui()
		return
	var saved_biochemistry: Dictionary = Biochemistry.serialize_state(biochemistry_state)
	if saved_biochemistry.is_empty():
		last_status = "The biochemical state could not be saved because it failed validation."
		_refresh_ui()
		return
	var record := {
		"version": SAVE_VERSION,
		"seed": START_SEED,
		"simulationTime": simulation_time,
		"cognition": Cognition.serialize_state(cognition_state),
		"language": saved_language,
		"biochemistry": saved_biochemistry
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		last_status = "Could not write local save (error %d)." % FileAccess.get_open_error()
		_refresh_ui()
		return
	file.store_string(JSON.stringify(record, "\t"))
	file.close()
	last_status = "Saved this Norn locally to %s." % SAVE_PATH
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
	var save_version := int(record.get("version", -1))
	if not [1, 2, SAVE_VERSION].has(save_version):
		_fallback_from_invalid_save("The save format is not valid")
		return
	if int(record.get("seed", -1)) != START_SEED or not _is_finite_number(record.get("simulationTime", null)):
		_fallback_from_invalid_save("The save metadata is not valid")
		return
	var saved_cognition = record.get("cognition", null)
	if not (saved_cognition is Dictionary):
		_fallback_from_invalid_save("The saved Norn state is missing")
		return
	var restored: Dictionary = Cognition.restore_state(saved_cognition)
	if restored.is_empty() or int(restored.get("seed", -1)) != START_SEED:
		_fallback_from_invalid_save("The saved Norn state failed validation")
		return
	var restored_biochemistry: Dictionary
	if save_version == SAVE_VERSION:
		restored_biochemistry = Biochemistry.restore_state(record.get("biochemistry", null))
		if restored_biochemistry.is_empty():
			_fallback_from_invalid_save("The saved biochemical state failed validation")
			return
	else:
		restored_biochemistry = Biochemistry.migrate_from_legacy_signals(restored["chemistry"])
		if restored_biochemistry.is_empty():
			_fallback_from_invalid_save("The legacy biochemical state failed migration")
			return
	var restored_language: Dictionary = _language.call("create_state")
	if save_version >= 2:
		restored_language = _language.call("restore_state", record.get("language", null))
		if restored_language.is_empty():
			_fallback_from_invalid_save("The saved vocabulary failed validation")
			return
	if not Cognition.sync_chemistry(restored, Biochemistry.read_signals(restored_biochemistry)):
		_fallback_from_invalid_save("The biochemical cognition signals failed validation")
		return
	cognition_state = restored
	biochemistry_state = restored_biochemistry
	language_state = restored_language
	teaching_mode = false
	if _ui != null:
		_ui.clear_teaching_input()
	simulation_time = maxf(0.0, float(record["simulationTime"]))
	_chemistry_accumulator = 0.0
	_decision_accumulator = 0.0
	guidance.clear()
	feedback_available = false
	_respawn_times.clear()
	for item: Interactable in objects.values():
		item.set_available(true)
	norn.reset_position(Vector3(3.0, 0.0, 2.0))
	last_status = "Loaded Mallow's local learning and memories."
	_run_decision()
	_refresh_ui()


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


func _apply_biochemistry_event(event_id: String, outcome: Dictionary) -> Dictionary:
	if cognition_state.is_empty() or biochemistry_state.is_empty():
		return {}
	var before: Dictionary = Biochemistry.read_signals(biochemistry_state)
	var applied: Dictionary = Biochemistry.apply_event(biochemistry_state, event_id)
	if applied.is_empty():
		return {}
	var after: Dictionary = Biochemistry.read_signals(biochemistry_state)
	if not Cognition.sync_chemistry(cognition_state, after):
		return {}
	return Cognition.record_outcome(cognition_state, outcome, {"before": before, "after": after})


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
	box.size = Vector3(24.0, 0.4, 18.0)
	floor_mesh.mesh = box
	floor_mesh.material_override = _material(Color(0.26, 0.39, 0.23))
	floor_mesh.position.y = -0.2
	floor_body.add_child(floor_mesh)
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = box.size
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.2
	floor_body.add_child(floor_collision)
	add_child(floor_body)
	_add_path(Vector3(4.0, 0.012, 0.0), Vector3(13.0, 0.025, 4.0))
	_add_tree(Vector3(-9.0, 0.0, -5.5), 1.2, Color(0.23, 0.42, 0.25))
	_add_tree(Vector3(-8.5, 0.0, 5.5), 1.0, Color(0.3, 0.48, 0.27))
	_add_tree(Vector3(8.5, 0.0, -5.0), 1.35, Color(0.22, 0.4, 0.23))
	_add_tree(Vector3(9.2, 0.0, 5.8), 1.1, Color(0.34, 0.48, 0.24))
	_add_rock(Vector3(-5.7, 0.18, -5.8), Vector3(1.1, 0.4, 0.8))
	_add_rock(Vector3(5.6, 0.16, 5.6), Vector3(1.2, 0.35, 0.7))
	_add_label("Sunmeadow", Vector3(-9.6, 0.3, -7.7), 28, Color(0.95, 0.88, 0.62))


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "HabitatCamera"
	_camera.current = true
	_camera.fov = 48.0
	add_child(_camera)
	_update_camera()


func _build_creature() -> void:
	norn = NornActor.new()
	norn.configure_identity("mallow", "Mallow", Color(0.43, 0.27, 0.16))
	norn.position = Vector3(3.0, 0.0, 2.0)
	norn.action_completed.connect(_on_action_completed)
	add_child(norn)


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
	spinner.position = Vector3(8.0, 0.0, -2.4)
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


func _run_decision() -> void:
	if cognition_state.is_empty() or norn == null:
		return
	var nearby_objects: Array[Dictionary] = []
	for item: Interactable in norn.sensed_interactables():
		nearby_objects.append({
			"id": item.object_id,
			"kind": item.kind,
			"label": item.display_name,
			"distance": norn.global_position.distance_to(item.global_position) * 90.0,
			"affordances": item.affordances.duplicate()
		})
	var active_guidance: Variant = guidance if not guidance.is_empty() and simulation_time <= float(guidance["expiresAt"]) else null
	var observation := {
		"time": simulation_time,
		"chemistry": cognition_state["chemistry"],
		"nearbyObjects": nearby_objects,
		"nearbyNorns": [],
		"guidance": active_guidance,
		"languageSignals": {}
	}
	var decision: Dictionary = Cognition.decide(cognition_state, observation)
	recalled_moments.clear()
	for episode in decision.get("recalled", []):
		if episode is Dictionary:
			recalled_moments.append(episode)
	var effective_action := str(decision.get("actionId", "idle"))
	var reason := str(decision.get("reason", "Looking around the habitat"))
	var target: Interactable
	if active_guidance is Dictionary and objects.has(active_guidance["objectId"]):
		effective_action = str(active_guidance["objectId"])
		target = objects[effective_action]
		reason = "Following your guidance to %s" % target.display_name.to_lower()
	elif ["fruit", "spinner"].has(effective_action) and objects.has(effective_action):
		target = objects[effective_action]
		if not target.available or not nearby_objects.any(func(entry: Dictionary) -> bool: return entry["id"] == effective_action):
			target = null
	if target == null:
		norn.set_action_target(null, effective_action, reason)
	else:
		norn.set_action_target(target, effective_action, reason)
	current_decision = decision.duplicate(true)
	current_decision["actionId"] = effective_action
	current_decision["reason"] = reason


func _on_action_completed(actor_id: String, action_id: String, target_id: String) -> void:
	if norn == null or actor_id != norn.actor_id:
		return
	if not objects.has(target_id):
		return
	var item: Interactable = objects[target_id]
	if not item.available:
		return
	var event_type := "food" if action_id == "fruit" else "toy"
	var actor_name := norn.display_name
	var outcome_text := "%s ate honey fruit" % actor_name if event_type == "food" else "%s played with the spinner" % actor_name
	item.activate()
	_respawn_times[target_id] = simulation_time + (6.0 if event_type == "food" else 4.0)
	var spoken_word: Dictionary = _language.call("word_for_target", language_state, target_id)
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
	var result: Dictionary = _apply_biochemistry_event(event_type, outcome)
	feedback_action = action_id
	feedback_target = target_id
	feedback_time = simulation_time
	feedback_available = true
	last_status = "%s. Learned association: %s %.2f (Δ %.2f)." % [
		outcome_text,
		action_id,
		float(result.get("association", 0.0)),
		float(result.get("learningDelta", 0.0))
	]
	if not spoken_word.is_empty():
		last_status += " %s said “%s”." % [actor_name, str(spoken_word["word"])]
	_run_decision()


func _update_timed_state() -> void:
	if not guidance.is_empty() and simulation_time > float(guidance.get("expiresAt", 0.0)):
		guidance.clear()
	for object_id: String in _respawn_times.keys():
		if simulation_time >= float(_respawn_times[object_id]):
			(objects[object_id] as Interactable).set_available(true)
			_respawn_times.erase(object_id)
	if feedback_available and simulation_time - feedback_time > FEEDBACK_WINDOW:
		feedback_available = false


func _fallback_from_invalid_save(reason: String) -> void:
	_reset_state(false)
	last_status = "%s; started a clean seeded Norn." % reason
	_refresh_ui()


func _reset_state(write_save: bool) -> void:
	cognition_state = _new_cognition_state()
	biochemistry_state = Biochemistry.create_state(cognition_state["chemistry"])
	Cognition.sync_chemistry(cognition_state, Biochemistry.read_signals(biochemistry_state))
	language_state = _language.call("create_state")
	teaching_mode = false
	if _ui != null:
		_ui.clear_teaching_input()
	simulation_time = 0.0
	_chemistry_accumulator = 0.0
	_decision_accumulator = 0.0
	guidance.clear()
	feedback_available = false
	feedback_action = ""
	feedback_target = ""
	_respawn_times.clear()
	for item: Interactable in objects.values():
		item.set_available(true)
	norn.reset_position(Vector3(3.0, 0.0, 2.0))
	current_decision.clear()
	recalled_moments.clear()
	_run_decision()
	if write_save:
		save_game()


func _refresh_ui() -> void:
	if _ui == null or cognition_state.is_empty():
		return
	_ui.update_view(
		cognition_state["chemistry"],
		current_decision,
		recalled_moments,
		last_status,
		paused,
		simulation_speed,
		feedback_available,
		video_recorder != null and video_recorder.is_recording(),
		video_recorder.recording_time() if video_recorder != null else 0.0,
		last_recording_path,
		video_recorder.last_error if video_recorder != null else "",
		recorded_frame_count,
		teaching_mode,
		language_state,
		Biochemistry.read_compounds(biochemistry_state),
		Biochemistry.read_fluxes(biochemistry_state)
	)


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
