extends SceneTree

const SURFACE_SCRIPT_PATH := "res://scripts/drawing_surface.gd"
const SURFACE_SIZE := 256
const SAMPLE_SIDE := 16
const MAX_STROKES := 256
const MAX_POINTS_PER_STROKE := 128
const BASELINE_DECISIONS := 300
const BASELINE_DT := 0.2
const SHUFFLE_REPLICATES := 64
const Cognition := preload("res://scripts/norn_cognition.gd")
const ACTOR_SCRIPT_PATH := "res://scripts/norn_actor.gd"
const WORLD_SCRIPT_PATH := "res://scripts/albia_world.gd"

var _failures: Array[String] = []
var _surface_script: Script


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	_surface_script = load(SURFACE_SCRIPT_PATH) as Script
	_expect(_surface_script != null, "drawing surface script is available")
	if _surface_script == null:
		_finish()
		return
	test_empty_surface_is_blank()
	test_point_bounds_and_actor_ids_are_validated()
	test_contact_builds_and_ends_strokes()
	test_completed_strokes_are_reported_once()
	test_sampling_reads_the_rendered_mark_pixels()
	test_strokes_and_texture_round_trip()
	test_cursor_state_survives_a_pen_up_round_trip()
	test_cursor_retention_is_bounded_across_authors()
	test_malformed_records_are_rejected_atomically()
	test_retention_caps_and_evicts_oldest_strokes()
	test_mark_input_is_appended_and_visibility_gated()
	test_draw_action_migrates_with_neutral_defaults()
	test_motor_command_is_bounded_and_deterministic()
	test_actor_has_a_movable_drawing_effector()
	test_draw_requires_visible_surface_and_tool()
	test_urgent_needs_override_draw()
	test_world_draw_objects_are_visible_and_range_gated()
	await test_world_executes_incremental_marks_and_records_stroke_outcome()
	test_legacy_world_saves_clear_the_drawing_surface()
	test_reset_and_invalid_save_fallback_clear_surface()
	test_version_6_save_restores_surface_atomically()
	test_maximum_surface_save_size_is_measured()
	test_seeded_mark_making_baseline()
	_finish()


func test_empty_surface_is_blank() -> void:
	var surface: Variant = _new_surface()
	var grid: PackedFloat32Array = surface.sample_mark_grid(Vector2(0.5, 0.5), SAMPLE_SIDE)
	_expect(grid.size() == SAMPLE_SIDE * SAMPLE_SIDE, "empty surface returns a complete sample grid")
	var all_blank := true
	for value: float in grid:
		all_blank = all_blank and is_zero_approx(value)
	_expect(all_blank, "empty surface sample contains no marks")
	_expect(surface.image is Image and surface.image.get_width() == SURFACE_SIZE and surface.image.get_height() == SURFACE_SIZE, "surface image has the bounded logical size")
	_expect(surface.texture is ImageTexture, "surface exposes its render texture")


func test_point_bounds_and_actor_ids_are_validated() -> void:
	var surface: Variant = _new_surface()
	_expect(surface.append_point("norn-1", Vector2.ZERO, 0.5, true), "origin point is accepted")
	_expect(surface.append_point("norn-1", Vector2.ONE, 1.0, true), "inclusive upper coordinate and pressure bounds are accepted")
	_expect(not surface.append_point("norn-1", Vector2(-0.01, 0.5), 0.5, true), "coordinates below the surface are rejected")
	_expect(not surface.append_point("norn-1", Vector2(0.5, 1.01), 0.5, true), "coordinates above the surface are rejected")
	_expect(not surface.append_point("norn-1", Vector2(0.5, 0.5), -0.01, true), "negative pressure is rejected")
	_expect(not surface.append_point("norn-1", Vector2(0.5, 0.5), 1.01, true), "pressure above the bound is rejected")
	_expect(not surface.append_point("", Vector2(0.5, 0.5), 0.5, true), "empty actor IDs are rejected")
	_expect(not surface.append_point("bad actor id", Vector2(0.5, 0.5), 0.5, true), "invalid actor IDs are rejected")


func test_contact_builds_and_ends_strokes() -> void:
	var surface: Variant = _new_surface()
	_expect(surface.append_point("norn-1", Vector2(0.4, 0.5), 0.5, true), "pen-down starts a stroke")
	_expect(surface.append_point("norn-1", Vector2(0.6, 0.5), 0.7, true), "contact appends a point to the active stroke")
	_expect(surface.append_point("norn-1", Vector2(0.6, 0.5), 0.7, false), "pen-up ends the active stroke")
	var state: Dictionary = surface.serialize_state()
	var strokes: Array = state.get("strokes", [])
	_expect(strokes.size() == 1, "pen-up leaves one completed stroke")
	var last_uv: Vector2 = surface.get_last_uv("norn-1")
	_expect(absf(last_uv.x - 0.6) <= 0.5 / 255.0 and absf(last_uv.y - 0.5) <= 1.0 / 255.0, "last contact position remains available at quantized precision")
	if strokes.size() == 1:
		_expect(strokes[0].get("points", []).size() == 2, "one stroke retains exactly its two contact points")
		_expect(not bool(strokes[0].get("active", true)), "pen-up marks the stroke as inactive")
	_expect(surface.append_point("norn-1", Vector2(0.7, 0.5), 0.4, false), "repeated pen-up is safe")
	_expect((surface.serialize_state().get("strokes", []) as Array).size() == 1, "pen-up without contact does not create an empty stroke")


func test_completed_strokes_are_reported_once() -> void:
	var surface: Variant = _new_surface()
	surface.append_point("norn-1", Vector2(0.3, 0.4), 0.4, true)
	surface.append_point("norn-1", Vector2(0.6, 0.7), 0.7, true)
	surface.append_point("norn-1", Vector2(0.6, 0.7), 0.7, false)
	var completed: Dictionary = surface.pop_completed_stroke("norn-1")
	_expect(completed.get("actorId", "") == "norn-1" and completed.get("points", []).size() == 2, "pen-up exposes the completed author stroke for event logging")
	_expect(surface.pop_completed_stroke("norn-1").is_empty(), "completed stroke event data is consumed once")


func test_sampling_reads_the_rendered_mark_pixels() -> void:
	var surface: Variant = _new_surface()
	var texture_id: int = surface.texture.get_instance_id()
	var blank: PackedFloat32Array = surface.sample_mark_grid(Vector2(0.2, 0.5), SAMPLE_SIDE)
	_expect(surface.append_point("norn-1", Vector2(0.2, 0.5), 1.0, true), "mark point is accepted")
	var local: PackedFloat32Array = surface.sample_mark_grid(Vector2(0.2, 0.5), SAMPLE_SIDE)
	var distant: PackedFloat32Array = surface.sample_mark_grid(Vector2(0.8, 0.5), SAMPLE_SIDE)
	var blank_sum := _sum_grid(blank)
	var local_sum := _sum_grid(local)
	var distant_sum := _sum_grid(distant)
	_expect(blank_sum < local_sum, "mark changes the nearby normalized perception grid")
	_expect(local_sum > distant_sum, "sensor origin selects a local patch of the surface")
	var valid_range := true
	var total_signal := 0.0
	for value: float in local:
		valid_range = valid_range and is_finite(value) and value >= 0.0 and value <= 1.0
		total_signal += value
	_expect(valid_range and total_signal > 0.0, "mark sample is finite, normalized, and contains ink")
	_expect(surface.texture.get_size() == Vector2(SURFACE_SIZE, SURFACE_SIZE), "render texture has the same dimensions as the perception image")
	_expect(surface.texture.get_instance_id() == texture_id, "existing render texture resource is updated after a mark")


func test_strokes_and_texture_round_trip() -> void:
	var surface: Variant = _new_surface()
	surface.append_point("norn-1", Vector2(0.25, 0.35), 0.3, true)
	surface.append_point("norn-1", Vector2(0.75, 0.65), 0.9, true)
	surface.append_point("norn-1", Vector2(0.75, 0.65), 0.9, false)
	var encoded: Dictionary = surface.serialize_state()
	var restored: Variant = _new_surface()
	_expect(restored.restore_state(encoded), "valid stroke state restores")
	if restored.serialize_state().is_empty():
		return
	_expect(surface.image.get_data() == restored.image.get_data(), "restored surface renders identical pixels")
	_expect(surface.sample_mark_grid(Vector2(0.5, 0.5), SAMPLE_SIDE) == restored.sample_mark_grid(Vector2(0.5, 0.5), SAMPLE_SIDE), "restored perception grid is deterministic")
	_expect(surface.serialize_state() == restored.serialize_state(), "stroke record round trip is deterministic")


func test_cursor_state_survives_a_pen_up_round_trip() -> void:
	var surface: Variant = _new_surface()
	surface.append_point("norn-1", Vector2(0.3, 0.35), 0.4, true)
	surface.append_point("norn-1", Vector2(0.8, 0.7), 0.0, false)
	var cursor: Vector2 = surface.get_last_uv("norn-1")
	_expect(absf(cursor.x - 0.8) <= 0.5 / 255.0 and absf(cursor.y - 0.7) <= 0.5 / 255.0, "pen-up updates the surface cursor without adding ink")
	var record: Dictionary = surface.serialize_state()
	_expect((record.get("cursors", []) as Array).size() == 1, "surface save stores one bounded cursor per author")
	var restored: Variant = _new_surface()
	_expect(restored.restore_state(record), "surface cursor record restores")
	_expect(restored.get_last_uv("norn-1").is_equal_approx(cursor), "restored cursor preserves the next perception window")


func test_cursor_retention_is_bounded_across_authors() -> void:
	var surface: Variant = _new_surface()
	for actor_index: int in range(5):
		var actor_id := "norn-%d" % (actor_index + 1)
		var uv := Vector2(0.1 + float(actor_index) * 0.1, 0.2 + float(actor_index) * 0.1)
		surface.append_point(actor_id, uv, 0.5, true)
		surface.append_point(actor_id, uv, 0.0, false)
	var record: Dictionary = surface.serialize_state()
	var cursors: Array = record.get("cursors", [])
	_expect(cursors.size() == 4, "surface keeps no more than four author cursors")
	_expect(cursors.size() == 4 and cursors[0].get("actorId", "") == "norn-2" and cursors[3].get("actorId", "") == "norn-5", "new authors evict only the least-recently-used cursor")
	_expect(surface.call("get_stroke_count") == 5, "evicting an old cursor keeps that author's historical mark")
	_expect(surface.get_last_uv("norn-1").is_equal_approx(Vector2(0.5, 0.5)), "evicted cursors fall back to the default center without deleting marks")
	var restored: Variant = _new_surface()
	_expect(restored.restore_state(record), "bounded multi-author cursor state restores")
	_expect(restored.serialize_state() == record, "cursor least-recently-used order survives save/load")
	restored.append_point("norn-2", Vector2(0.4, 0.5), 0.0, false)
	restored.append_point("norn-6", Vector2(0.8, 0.5), 0.0, false)
	var touched_record: Dictionary = restored.serialize_state()
	var touched_cursors: Array = touched_record.get("cursors", [])
	_expect(touched_cursors.size() == 4 and touched_cursors[0].get("actorId", "") == "norn-4" and touched_cursors[3].get("actorId", "") == "norn-6", "using a cursor refreshes its recency before the next eviction")


func test_malformed_records_are_rejected_atomically() -> void:
	var surface: Variant = _new_surface()
	surface.append_point("norn-1", Vector2(0.5, 0.5), 0.5, true)
	var before: PackedByteArray = surface.image.get_data()
	var malformed: Dictionary = surface.serialize_state()
	malformed["version"] = 999
	_expect(not surface.restore_state(malformed), "unsupported surface schema is rejected")
	_expect(surface.image.get_data() == before, "failed restore leaves current pixels unchanged")
	malformed = surface.serialize_state()
	var strokes: Array = malformed["strokes"]
	var points: Array = strokes[0]["points"]
	points[0]["x"] = SURFACE_SIZE
	_expect(not surface.restore_state(malformed), "out-of-range serialized coordinates are rejected")
	_expect(surface.image.get_data() == before, "malformed points do not partially replace the image")
	_expect(not surface.restore_state({"version": 1, "strokes": "not-an-array"}), "wrong serialized field types are rejected")
	var too_many: Array[Dictionary] = []
	for stroke_index: int in range(MAX_STROKES + 1):
		too_many.append({"actorId": "norn-1", "active": false, "points": [{"x": 1, "y": 1, "pressure": 100}]})
	_expect(not surface.restore_state({"version": 1, "strokes": too_many}), "surface records above the retained-stroke cap are rejected")
	_expect(surface.image.get_data() == before, "over-cap stroke data does not replace live pixels")


func test_retention_caps_and_evicts_oldest_strokes() -> void:
	var surface: Variant = _new_surface()
	for stroke_index: int in range(MAX_STROKES + 1):
		var x := float(stroke_index % SURFACE_SIZE) / float(SURFACE_SIZE - 1)
		_expect(surface.append_point("norn-1", Vector2(x, 0.5), 0.5, true), "bounded stroke point is accepted")
		surface.append_point("norn-1", Vector2(x, 0.5), 0.5, false)
	var strokes: Array = surface.serialize_state().get("strokes", [])
	_expect(strokes.size() == MAX_STROKES, "surface retains no more than the stroke limit")
	if not strokes.is_empty():
		_expect(int(strokes[0]["points"][0]["x"]) != 0, "oldest complete stroke is evicted at the cap")
	for point_index: int in range(MAX_POINTS_PER_STROKE + 1):
		surface.append_point("norn-2", Vector2(float(point_index % SURFACE_SIZE) / float(SURFACE_SIZE - 1), 0.2), 0.5, true)
	var point_strokes: Array = surface.serialize_state().get("strokes", [])
	var within_cap := true
	for stroke: Dictionary in point_strokes:
		within_cap = within_cap and stroke["points"].size() <= MAX_POINTS_PER_STROKE
	_expect(within_cap, "no retained stroke exceeds the point limit")
	_expect(point_strokes.size() <= MAX_STROKES, "point rollover respects the total stroke limit")


func test_mark_input_is_appended_and_visibility_gated() -> void:
	var state: Dictionary = Cognition.create_state(901)
	var marks := PackedFloat32Array()
	marks.resize(SAMPLE_SIDE * SAMPLE_SIDE)
	marks.fill(0.0)
	var changed_marks := marks.duplicate()
	changed_marks[73] = 0.8
	var visible_objects: Array[Dictionary] = [{"id": "drawing_surface", "distance": 4.0}]
	var blank: Array[float] = Cognition._get_input_vector(state, {"nearbyObjects": visible_objects, "surfaceMarks": marks})
	var changed: Array[float] = Cognition._get_input_vector(state, {"nearbyObjects": visible_objects, "surfaceMarks": changed_marks})
	var hidden: Array[float] = Cognition._get_input_vector(state, {"nearbyObjects": [], "surfaceMarks": changed_marks})
	_expect(blank.size() == 276 and changed.size() == 276 and hidden.size() == 276, "cognition input contains 20 named signals and 256 visual marks")
	if blank.size() == 276 and changed.size() == 276 and hidden.size() == 276:
		_expect(is_zero_approx(blank[20 + 73]) and is_equal_approx(changed[20 + 73], 0.8), "surface mark changes its matching visual input")
		_expect(is_zero_approx(hidden[20 + 73]), "marks are hidden when the surface is not in the visible observation")


func test_draw_action_migrates_with_neutral_defaults() -> void:
	var ids: Array[String] = Cognition.get_action_ids()
	_expect(ids.has("draw"), "draw is an available cognition action")
	var legacy: Dictionary = Cognition.serialize_state(Cognition.create_state(902))
	legacy["version"] = 2
	legacy["actionAssociations"].erase("draw")
	legacy["contextAssociations"].erase("draw")
	legacy["eligibility"].erase("draw")
	legacy["contextEligibility"].erase("draw")
	var restored: Dictionary = Cognition.restore_state(legacy)
	_expect(not restored.is_empty(), "version-2 cognition state migrates after adding draw")
	if not restored.is_empty() and ids.has("draw"):
		_expect(is_equal_approx(float(restored["actionAssociations"]["draw"]), 0.5), "migrated draw association starts neutral")
		_expect(is_zero_approx(float(restored["eligibility"]["draw"])), "migrated draw eligibility starts empty")
		_expect(is_equal_approx(float(restored["contextAssociations"]["draw"]["curious"]), 0.5), "migrated draw context starts neutral")


func test_motor_command_is_bounded_and_deterministic() -> void:
	var initial := {"hunger": 5.0, "curiosity": 100.0, "fatigue": 0.0, "actionAssociations": {"draw": 1.0}}
	var traits := {"curiosity": 0.9, "sociability": 0.4}
	var first_state: Dictionary = Cognition.create_state(903, traits, initial)
	var second_state: Dictionary = Cognition.create_state(903, traits, initial)
	var observation := {
		"chemistry": first_state["chemistry"],
		"nearbyObjects": [{"id": "drawing_surface", "distance": 2.0}, {"id": "charcoal", "distance": 1.0}],
		"nearbyNorns": [],
		"surfaceMarks": PackedFloat32Array()
	}
	var first_decision: Dictionary = Cognition.preview(first_state, observation)
	var second_decision: Dictionary = Cognition.preview(second_state, observation)
	_expect(str(first_decision.get("actionId", "")) == "draw", "curiosity and a strong draw association can select a visible surface")
	var command: Dictionary = first_decision.get("drawMotorCommand", {})
	var second_command: Dictionary = second_decision.get("drawMotorCommand", {})
	_expect(command.has("dx") and command.has("dy") and command.has("pressure") and command.has("contact"), "draw decision exposes a complete motor command")
	if command.has("dx") and command.has("dy") and command.has("pressure") and command.has("contact"):
		_expect(absf(float(command["dx"])) <= 0.12 and absf(float(command["dy"])) <= 0.12, "motor deltas stay within the surface-local bound")
		_expect(float(command["pressure"]) >= 0.0 and float(command["pressure"]) <= 1.0, "motor pressure remains normalized")
		_expect(command["contact"] is bool, "motor contact state is boolean")
		_expect(command == second_command, "same seed and recurrent state produce the same motor command")


func test_actor_has_a_movable_drawing_effector() -> void:
	var actor_script: Script = load(ACTOR_SCRIPT_PATH) as Script
	_expect(actor_script != null, "Norn actor script is available")
	if actor_script == null:
		return
	var actor: Node3D = actor_script.new() as Node3D
	root.add_child(actor)
	var visuals: Node3D = actor.get_node_or_null("LifeStageVisuals") as Node3D
	var effector: Node3D = visuals.get_node_or_null("DrawingEffector") as Node3D if visuals != null else null
	_expect(effector != null, "procedural Norn body includes a drawing effector")
	if effector != null:
		var hand: Node3D = effector.get_node_or_null("Hand") as Node3D
		_expect(hand != null, "drawing effector includes a movable hand")
		if hand != null:
			var rest_position := hand.position
			_expect(actor.has_method("set_drawing_effector_pose"), "actor exposes a drawing pose update")
			if actor.has_method("set_drawing_effector_pose"):
				actor.call("set_drawing_effector_pose", Vector3(0.5, 1.25, -1.0), true)
				actor.call("_process", 1.0)
				_expect(not hand.position.is_equal_approx(rest_position), "drawing hand moves toward a contact point")
	actor.queue_free()


func test_draw_requires_visible_surface_and_tool() -> void:
	var state: Dictionary = Cognition.create_state(904, {"curiosity": 0.9}, {
		"hunger": 5.0,
		"curiosity": 100.0,
		"fatigue": 0.0,
		"actionAssociations": {"draw": 1.0}
	})
	var surface := {"id": "drawing_surface", "distance": 2.0}
	var tool := {"id": "charcoal", "distance": 2.0}
	var available := Cognition.preview(state, {"nearbyObjects": [surface, tool], "nearbyNorns": []})
	var missing_surface := Cognition.preview(state, {"nearbyObjects": [tool], "nearbyNorns": []})
	var missing_tool := Cognition.preview(state, {"nearbyObjects": [surface], "nearbyNorns": []})
	var unavailable_tool := Cognition.preview(state, {"nearbyObjects": [surface, {"id": "charcoal", "available": false}], "nearbyNorns": []})
	_expect((available.get("eligibleActions", []) as Array).has("draw"), "draw is eligible when both required objects are visible")
	_expect(not (missing_surface.get("eligibleActions", []) as Array).has("draw"), "draw is gated when the surface is not visible")
	_expect(not (missing_tool.get("eligibleActions", []) as Array).has("draw"), "draw is gated when the tool is not visible")
	_expect(not (unavailable_tool.get("eligibleActions", []) as Array).has("draw"), "draw is gated when the tool is unavailable")


func test_urgent_needs_override_draw() -> void:
	var draw_objects := [
		{"id": "drawing_surface", "distance": 2.0},
		{"id": "charcoal", "distance": 2.0},
		{"id": "fruit", "distance": 1.0}
	]
	var hungry_state: Dictionary = Cognition.create_state(905, {"curiosity": 1.0}, {
		"hunger": 95.0,
		"curiosity": 100.0,
		"fatigue": 0.0,
		"actionAssociations": {"draw": 1.0}
	})
	var hungry_decision: Dictionary = Cognition.preview(hungry_state, {"nearbyObjects": draw_objects, "nearbyNorns": []})
	_expect(str(hungry_decision.get("actionId", "")) == "fruit" and str(hungry_decision.get("safetyOverride", "")) == "fruit", "urgent hunger keeps priority over drawing")
	var tired_state: Dictionary = Cognition.create_state(906, {"curiosity": 1.0}, {
		"hunger": 5.0,
		"curiosity": 100.0,
		"fatigue": 100.0,
		"actionAssociations": {"draw": 1.0}
	})
	var tired_decision: Dictionary = Cognition.preview(tired_state, {"nearbyObjects": draw_objects, "nearbyNorns": []})
	_expect(str(tired_decision.get("actionId", "")) == "rest" and str(tired_decision.get("safetyOverride", "")) == "rest", "urgent fatigue keeps priority over drawing")


func test_world_draw_objects_are_visible_and_range_gated() -> void:
	var world_script := load(WORLD_SCRIPT_PATH) as Script
	_expect(world_script != null, "habitat world script is available")
	if world_script == null:
		return
	var world: Node3D = world_script.new() as Node3D
	root.add_child(world)
	world.set("paused", true)
	var profile: Variant = world.call("profile_for", "mallow")
	var surface_value: Variant = world.get("drawing_surface")
	_expect(surface_value != null, "habitat owns one shared drawing surface")
	_expect((world.get("objects") as Dictionary).has("drawing_surface"), "habitat registers the drawing surface as an interactable")
	_expect((world.get("objects") as Dictionary).has("charcoal"), "habitat registers the charcoal tool as an interactable")
	var preview_label := world.find_child("DrawingSurfaceLabel", true, false) as Label
	var preview_texture := world.find_child("DrawingSurfacePreview", true, false) as TextureRect
	_expect(preview_label != null and preview_label.text.contains("Shared mark surface"), "HUD identifies the shared mark surface")
	_expect(surface_value != null and preview_texture != null and preview_texture.texture == surface_value.get("texture"), "HUD exposes the same inspectable texture the board renders")
	if profile != null:
		var sensed: Array = world.call("_sense_objects", profile)
		_expect(_sensed_has(sensed, "drawing_surface") and _sensed_has(sensed, "charcoal"), "nearby Norn senses both drawing objects")
		var charcoal: Interactable = (world.get("objects") as Dictionary)["charcoal"] as Interactable
		charcoal.set_available(false)
		var tool_unavailable: Array = world.call("_sense_objects", profile)
		_expect(_sensed_has(tool_unavailable, "drawing_surface") and not _sensed_has(tool_unavailable, "charcoal"), "unavailable charcoal drops out of the reachable observation")
		charcoal.set_available(true)
		var actor: Node3D = profile.get("actor") as Node3D
		if actor != null:
			actor.global_position = Vector3(100.0, 0.0, 100.0)
			var far_sensed: Array = world.call("_sense_objects", profile)
			_expect(not _sensed_has(far_sensed, "drawing_surface") and not _sensed_has(far_sensed, "charcoal"), "drawing objects are unavailable outside world sense range")
	world.free()


func test_world_executes_incremental_marks_and_records_stroke_outcome() -> void:
	var world_script := load(WORLD_SCRIPT_PATH) as Script
	if world_script == null:
		return
	var world: Node3D = world_script.new() as Node3D
	root.add_child(world)
	world.set("paused", true)
	var profile: Variant = world.call("profile_for", "mallow")
	var drawing_surface: Variant = world.get("drawing_surface")
	var objects: Dictionary = world.get("objects")
	if profile == null or drawing_surface == null or not objects.has("drawing_surface"):
		_expect(false, "world draw state is available for the incremental drawing check")
		world.free()
		return
	var surface_item: Node3D = objects["drawing_surface"] as Node3D
	var actor: Node3D = profile.get("actor") as Node3D
	actor.global_position = surface_item.global_position + Vector3(0.0, 0.0, 0.8)
	actor.set_physics_process(false)
	await process_frame
	var blank: PackedFloat32Array = drawing_surface.call("sample_mark_grid", Vector2(0.5, 0.5), SAMPLE_SIDE)
	var initial_draw_association := float(profile.get("cognition_state")["actionAssociations"]["draw"])
	var first_step := {"dx": 0.0, "dy": 0.0, "pressure": 0.6, "contact": true}
	var released_step := {"dx": 0.0, "dy": 0.0, "pressure": 0.6, "contact": false}
	_expect(bool(world.call("_execute_draw_step", profile, first_step)), "one draw decision appends a single contact point")
	var marked: PackedFloat32Array = drawing_surface.call("sample_mark_grid", Vector2(0.5, 0.5), SAMPLE_SIDE)
	var distant: PackedFloat32Array = drawing_surface.call("sample_mark_grid", Vector2(0.92, 0.5), SAMPLE_SIDE)
	_expect(_sum_grid(marked) > _sum_grid(blank), "incremental contact changes the local surface sample")
	_expect(_sum_grid(marked) > _sum_grid(distant), "incremental contact remains local to its intended area")
	var visible_objects: Array[Dictionary] = world.call("_sense_objects", profile)
	var input := Cognition._get_input_vector(profile.get("cognition_state"), {
		"nearbyObjects": visible_objects,
		"surfaceMarks": marked
	})
	var has_visual_mark := false
	for mark_index: int in range(SAMPLE_SIDE * SAMPLE_SIDE):
		has_visual_mark = has_visual_mark or float(input[20 + mark_index]) > 0.0
	_expect(has_visual_mark, "the next visible observation receives the changed mark grid")
	_expect(bool(world.call("_execute_draw_step", profile, released_step)), "pen-up closes the incremental stroke")
	var cognition_state: Dictionary = profile.get("cognition_state")
	var episodes: Array = cognition_state.get("episodes", [])
	var draw_event: Dictionary = episodes[episodes.size() - 1] if not episodes.is_empty() else {}
	_expect(draw_event.get("eventType", "") == "draw-mark" and draw_event.get("actorId", "") == "mallow", "a completed stroke records its author and draw event")
	_expect(draw_event.get("surfaceId", "") == "drawing_surface" and draw_event.get("toolId", "") == "charcoal", "a completed stroke event identifies its surface and tool")
	_expect(draw_event.get("strokeData", {}).get("pointCount", 0) == 1, "stroke event stores bounded endpoint and point-count data")
	_expect(is_zero_approx(float(draw_event.get("valence", 1))) and is_equal_approx(float(cognition_state["actionAssociations"]["draw"]), initial_draw_association), "making marks does not add an intrinsic reward or learning update")
	var restored: Dictionary = Cognition.restore_state(Cognition.serialize_state(cognition_state))
	_expect(not restored.is_empty(), "draw event survives cognition state validation and round-trip")
	world.free()


func test_legacy_world_saves_clear_the_drawing_surface() -> void:
	var world_script := load(WORLD_SCRIPT_PATH) as Script
	if world_script == null:
		return
	var world: Node3D = world_script.new() as Node3D
	root.add_child(world)
	world.set("paused", true)
	var candidates: Array[Dictionary] = []
	for version: int in [1, 2, 3]:
		var profile: Variant = world.call("profile_for", "mallow")
		var legacy := {
			"version": version,
			"seed": 4181996,
			"simulationTime": 0.0,
			"cognition": Cognition.serialize_state(profile.get("cognition_state"))
		}
		if version >= 2:
			legacy["language"] = world.get("_language").call("serialize_state", profile.get("language_state"))
		if version >= 3:
			legacy["biochemistry"] = load("res://scripts/norn_biochemistry.gd").serialize_state(profile.get("biochemistry_state"))
		candidates.append(world.call("_restore_legacy_record", legacy, version, 0.0))
	var family_record := _current_family_record(world, 5)
	candidates.append(world.call("_restore_version4_record", family_record, 0.0))
	candidates.append(world.call("_restore_version5_record", family_record, 0.0))
	for index: int in range(candidates.size()):
		var candidate: Dictionary = candidates[index]
		_expect(not candidate.is_empty(), "legacy version-%d fixture remains valid" % (index + 1))
		if candidate.is_empty():
			continue
		var drawing_surface: Variant = world.get("drawing_surface")
		drawing_surface.call("append_point", "mallow", Vector2(0.5, 0.5), 0.5, true)
		world.call("_apply_restored_world", candidate, 0.0)
		var surface_state: Dictionary = drawing_surface.call("serialize_state")
		_expect((surface_state.get("strokes", []) as Array).is_empty(), "legacy save version-%d restores an empty drawing surface" % (index + 1))
	world.free()


func test_reset_and_invalid_save_fallback_clear_surface() -> void:
	var world_script := load(WORLD_SCRIPT_PATH) as Script
	if world_script == null:
		return
	var world: Node3D = world_script.new() as Node3D
	root.add_child(world)
	world.set("paused", true)
	var drawing_surface: Variant = world.get("drawing_surface")
	var texture_id: int = drawing_surface.get("texture").get_instance_id()
	drawing_surface.call("append_point", "mallow", Vector2(0.4, 0.5), 0.7, true)
	_expect(drawing_surface.call("get_stroke_count") == 1, "reset fixture begins with a visible mark")
	_expect(not drawing_surface.call("get_last_uv", "mallow").is_equal_approx(Vector2(0.5, 0.5)), "reset fixture has a moved surface cursor")
	world.call("_reset_state", false)
	_expect(drawing_surface.call("get_stroke_count") == 0, "manual reset clears the shared drawing surface")
	_expect(drawing_surface.call("get_last_uv", "mallow").is_equal_approx(Vector2(0.5, 0.5)), "manual reset clears the old author cursor")
	_expect(drawing_surface.get("texture").get_instance_id() == texture_id, "reset keeps the board and HUD texture resource stable")
	_expect(_sum_grid(drawing_surface.call("sample_mark_grid", Vector2(0.5, 0.5), SAMPLE_SIDE)) == 0.0, "reset clears the mark perception grid")
	drawing_surface.call("append_point", "mallow", Vector2(0.6, 0.5), 0.7, true)
	world.call("_fallback_from_invalid_save", "Invalid test save")
	_expect(drawing_surface.call("get_stroke_count") == 0, "invalid-save fallback clears marks from the previous run")
	_expect(drawing_surface.call("get_last_uv", "mallow").is_equal_approx(Vector2(0.5, 0.5)), "invalid-save fallback clears the previous run's cursor")
	_expect(drawing_surface.get("texture").get_instance_id() == texture_id, "invalid-save fallback keeps the board texture connected")
	world.free()


func test_version_6_save_restores_surface_atomically() -> void:
	var world_script := load(WORLD_SCRIPT_PATH) as Script
	if world_script == null:
		return
	var world: Node3D = world_script.new() as Node3D
	root.add_child(world)
	world.set("paused", true)
	var drawing_surface: Variant = world.get("drawing_surface")
	drawing_surface.call("append_point", "mallow", Vector2(0.3, 0.35), 0.4, true)
	drawing_surface.call("append_point", "mallow", Vector2(0.7, 0.65), 0.8, true)
	drawing_surface.call("append_point", "mallow", Vector2(0.7, 0.65), 0.8, false)
	var expected_state: Dictionary = drawing_surface.call("serialize_state")
	var record := _current_family_record(world, 6)
	record["drawingSurface"] = expected_state
	_expect(world.has_method("_restore_version6_record"), "world provides a version-6 restore validator")
	if not world.has_method("_restore_version6_record"):
		world.free()
		return
	var candidate: Dictionary = world.call("_restore_version6_record", record, 0.0)
	_expect(not candidate.is_empty(), "valid version-6 save validates with surface data")
	var before_invalid: PackedByteArray = drawing_surface.get("image").get_data()
	var malformed := record.duplicate(true)
	malformed["drawingSurface"] = {"version": 1, "strokes": "invalid"}
	_expect((world.call("_restore_version6_record", malformed, 0.0) as Dictionary).is_empty(), "malformed version-6 surface data rejects the full save")
	_expect(drawing_surface.get("image").get_data() == before_invalid, "failed version-6 validation leaves the active surface unchanged")
	if not candidate.is_empty():
		world.call("_apply_restored_world", candidate, 0.0)
		_expect(drawing_surface.call("serialize_state") == expected_state, "version-6 apply restores exact stroke and cursor data")
	world.free()


func test_maximum_surface_save_size_is_measured() -> void:
	var world_script := load(WORLD_SCRIPT_PATH) as Script
	if world_script == null:
		return
	var world: Node3D = world_script.new() as Node3D
	root.add_child(world)
	world.set("paused", true)
	var maximum_surface := _maximum_surface_state()
	var surface: Variant = _new_surface()
	_expect(surface.restore_state(maximum_surface), "maximum retained surface state is valid")
	var record := _current_family_record(world, 6)
	record["drawingSurface"] = maximum_surface
	var bytes := JSON.stringify(record).to_utf8_buffer().size()
	print("DRAWING_SAVE_JSON_BYTES_AT_CAP=%d" % bytes)
	_expect(bytes > 0, "full version-6 JSON save size is measured at surface caps")
	world.free()


func test_seeded_mark_making_baseline() -> void:
	var single := _run_seeded_mark_session(1)
	var paired := _run_seeded_mark_session(2)
	_expect(single.get("durationSeconds", 0.0) == paired.get("durationSeconds", -1.0), "one- and two-Norn seeded sessions have matched duration")
	_expect(single.get("seed", -1) == paired.get("matchedSeed", -2), "the first Norn uses the same seed in both session sizes")
	_expect(single.get("actions", 0) >= BASELINE_DECISIONS and paired.get("actions", 0) >= BASELINE_DECISIONS * 2, "matched seeded sessions produce bounded decision samples")
	_expect(single.get("motorSteps", 0) > 0 and paired.get("motorSteps", 0) > 0, "both session sizes produce motor commands")
	_expect(single.get("strokes", 0) > 1 and paired.get("strokes", 0) > 1, "both session sizes retain multiple exploratory strokes")
	_expect(single.get("meanEndpointQuantizationError", 1.0) <= sqrt(2.0) / 510.0 + 0.00001, "single-Norn saved endpoints stay within half-pixel quantization error")
	_expect(paired.get("meanEndpointQuantizationError", 1.0) <= sqrt(2.0) / 510.0 + 0.00001, "two-Norn saved endpoints stay within half-pixel quantization error")
	_expect(single.get("saveGrowthBytes", -1) > 0 and paired.get("saveGrowthBytes", -1) > 0, "full version-6 save growth is measured for both sessions")
	print("DRAWING_BASELINE norns=1 matched_seed=%d duration_sim_s=%.1f decisions=%d motor_steps=%d strokes=%d closure_rate=%.3f endpoint_quantization_mean=%.6f motif_recurrence=%.3f shuffled_point_order_mean=%.3f save_growth_bytes=%d" % [
		int(single["seed"]), float(single["durationSeconds"]), int(single["actions"]), int(single["motorSteps"]), int(single["strokes"]), float(single["closureRate"]), float(single["meanEndpointQuantizationError"]), float(single["motifRecurrence"]), float(single["shuffledRecurrence"]), int(single["saveGrowthBytes"])
	])
	print("DRAWING_BASELINE norns=2 matched_seed=%d second_seed=%d duration_sim_s=%.1f decisions=%d motor_steps=%d strokes=%d closure_rate=%.3f endpoint_quantization_mean=%.6f motif_recurrence=%.3f shuffled_point_order_mean=%.3f save_growth_bytes=%d" % [
		int(paired["matchedSeed"]), int(paired["secondSeed"]), float(paired["durationSeconds"]), int(paired["actions"]), int(paired["motorSteps"]), int(paired["strokes"]), float(paired["closureRate"]), float(paired["meanEndpointQuantizationError"]), float(paired["motifRecurrence"]), float(paired["shuffledRecurrence"]), int(paired["saveGrowthBytes"])
	])
	_expect(float(single.get("durationSeconds", 0.0)) == float(BASELINE_DECISIONS) * BASELINE_DT, "baseline duration is reported in simulated seconds")
	_expect(float(paired.get("durationSeconds", 0.0)) == float(BASELINE_DECISIONS) * BASELINE_DT, "paired baseline duration is reported in simulated seconds")


func _run_seeded_mark_session(norn_count: int) -> Dictionary:
	var session_surface: Variant = _new_surface()
	var actor_ids: Array[String] = ["mallow"]
	if norn_count >= 2:
		actor_ids.append("moss")
	var states: Dictionary = {}
	var contact_by_actor: Dictionary = {}
	var starts_by_actor: Dictionary = {}
	var closures_by_actor: Dictionary = {}
	var all_strokes_by_actor: Dictionary = {}
	for actor_index: int in range(actor_ids.size()):
		var actor_id := actor_ids[actor_index]
		var seed := 9901 + actor_index
		states[actor_id] = Cognition.create_state(seed, {"curiosity": 0.9, "sociability": 0.5}, {
			"hunger": 5.0,
			"curiosity": 100.0,
			"fatigue": 5.0,
			"actionAssociations": {"draw": 1.0}
		})
		contact_by_actor[actor_id] = false
		starts_by_actor[actor_id] = 0
		closures_by_actor[actor_id] = 0
		all_strokes_by_actor[actor_id] = []
	var endpoint_error_total := 0.0
	var motor_steps := 0
	var drawing_actions := 0
	for decision_index: int in range(BASELINE_DECISIONS):
		for actor_id: String in actor_ids:
			var cognition_state: Dictionary = states[actor_id]
			var cursor: Vector2 = session_surface.call("get_last_uv", actor_id)
			var visible_marks: PackedFloat32Array = session_surface.call("sample_mark_grid", cursor, SAMPLE_SIDE)
			var observation := {
				"chemistry": cognition_state["chemistry"],
				"nearbyObjects": [
					{"id": "drawing_surface", "distance": 2.0},
					{"id": "charcoal", "distance": 1.5}
				],
				"nearbyNorns": [],
				"surfaceMarks": visible_marks
			}
			var decision: Dictionary = Cognition.decide(cognition_state, observation)
			states[actor_id] = cognition_state
			if str(decision.get("actionId", "")) != "draw":
				continue
			drawing_actions += 1
			var command: Dictionary = decision.get("drawMotorCommand", {})
			if command.is_empty():
				continue
			var intended := Vector2(
				clampf(cursor.x + clampf(float(command["dx"]), -0.08, 0.08), 0.03, 0.97),
				clampf(cursor.y + clampf(float(command["dy"]), -0.08, 0.08), 0.03, 0.97)
			)
			var contact := bool(command["contact"])
			var was_in_contact := bool(contact_by_actor[actor_id])
			if contact and not was_in_contact:
				starts_by_actor[actor_id] = int(starts_by_actor[actor_id]) + 1
			if not contact and was_in_contact:
				closures_by_actor[actor_id] = int(closures_by_actor[actor_id]) + 1
			var pressure := clampf(float(command["pressure"]), 0.05, 0.85)
			if not bool(session_surface.call("append_point", actor_id, intended, pressure if contact else 0.0, contact)):
				continue
			contact_by_actor[actor_id] = contact
			var persisted: Vector2 = session_surface.call("get_last_uv", actor_id)
			endpoint_error_total += intended.distance_to(persisted)
			motor_steps += 1
	for actor_id: String in actor_ids:
		var cursor: Vector2 = session_surface.call("get_last_uv", actor_id)
		session_surface.call("append_point", actor_id, cursor, 0.0, false)
		contact_by_actor[actor_id] = false
	var saved_surface: Dictionary = session_surface.call("serialize_state")
	var strokes: Array = saved_surface.get("strokes", [])
	for stroke: Dictionary in strokes:
		var actor_id := str(stroke.get("actorId", ""))
		if all_strokes_by_actor.has(actor_id):
			(all_strokes_by_actor[actor_id] as Array).append(stroke)
	var motif_scores: Array[float] = []
	var shuffled_scores: Array[float] = []
	var starts_total := 0
	var closures_total := 0
	for actor_id: String in actor_ids:
		starts_total += int(starts_by_actor[actor_id])
		closures_total += int(closures_by_actor[actor_id])
		var authored: Array = all_strokes_by_actor[actor_id]
		motif_scores.append(_motif_recurrence(authored))
		shuffled_scores.append(_shuffled_motif_recurrence(authored, 12000 + int(states[actor_id]["seed"])))
	var recurrence_total := 0.0
	var shuffled_total := 0.0
	for index: int in range(motif_scores.size()):
		recurrence_total += motif_scores[index]
		shuffled_total += shuffled_scores[index]
	var motif_average := recurrence_total / float(maxi(1, motif_scores.size()))
	var shuffled_average := shuffled_total / float(maxi(1, shuffled_scores.size()))
	var world_script := load(WORLD_SCRIPT_PATH) as Script
	var save_growth_bytes := -1
	if world_script != null:
		var world: Node3D = world_script.new() as Node3D
		root.add_child(world)
		world.set("paused", true)
		var save_record := _current_family_record(world, 6)
		var saved_profiles: Dictionary = save_record["norns"]
		for actor_id: String in actor_ids:
			if saved_profiles.has(actor_id):
				var profile_record: Dictionary = saved_profiles[actor_id]
				profile_record["cognition"] = Cognition.serialize_state(states[actor_id])
				saved_profiles[actor_id] = profile_record
		save_record["norns"] = saved_profiles
		var empty_record: Dictionary = save_record.duplicate(true)
		empty_record["drawingSurface"] = _new_surface().serialize_state()
		save_record["drawingSurface"] = saved_surface
		save_growth_bytes = JSON.stringify(save_record).to_utf8_buffer().size() - JSON.stringify(empty_record).to_utf8_buffer().size()
		world.queue_free()
	return {
		"seed": 9901,
		"matchedSeed": 9901,
		"secondSeed": 9902,
		"durationSeconds": float(BASELINE_DECISIONS) * BASELINE_DT,
		"actions": drawing_actions,
		"motorSteps": motor_steps,
		"strokes": strokes.size(),
		"closureRate": float(closures_total) / float(maxi(1, starts_total)),
		"meanEndpointQuantizationError": endpoint_error_total / float(maxi(1, motor_steps)),
		"motifRecurrence": motif_average,
		"shuffledRecurrence": shuffled_average,
		"saveGrowthBytes": save_growth_bytes
	}


func _motif_signature(stroke: Dictionary) -> String:
	var points: Array = stroke.get("points", [])
	if points.is_empty():
		return "empty"
	var first: Dictionary = points[0]
	var last: Dictionary = points[points.size() - 1]
	var dx := float(int(last.get("x", 0)) - int(first.get("x", 0)))
	var dy := float(int(last.get("y", 0)) - int(first.get("y", 0)))
	var distance_uv := Vector2(dx, dy).length() / 255.0
	var length_bin := 0 if distance_uv < 0.02 else 1 if distance_uv < 0.05 else 2 if distance_uv < 0.10 else 3
	var direction_bin := 8 if Vector2(dx, dy).length_squared() <= 1.0 else posmod(floori((atan2(dy, dx) + PI) / TAU * 8.0), 8)
	var count_bin := 0 if points.size() == 1 else 1 if points.size() <= 3 else 2 if points.size() <= 7 else 3
	return "%d:%d:%d" % [direction_bin, length_bin, count_bin]


func _motif_recurrence(strokes: Array) -> float:
	var signatures: Dictionary = {}
	for stroke_value: Variant in strokes:
		if stroke_value is Dictionary:
			var signature := _motif_signature(stroke_value)
			signatures[signature] = int(signatures.get(signature, 0)) + 1
	var pair_count := strokes.size() * (strokes.size() - 1) / 2
	if pair_count <= 0:
		return 0.0
	var repeated_pairs := 0
	for count_value: Variant in signatures.values():
		var count := int(count_value)
		repeated_pairs += count * (count - 1) / 2
	return float(repeated_pairs) / float(pair_count)


func _shuffled_motif_recurrence(strokes: Array, seed: int) -> float:
	if strokes.size() < 2:
		return 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var mean_score := 0.0
	for replicate: int in range(SHUFFLE_REPLICATES):
		var shuffled_strokes: Array = []
		for stroke_value: Variant in strokes:
			if not (stroke_value is Dictionary):
				continue
			var shuffled_stroke: Dictionary = (stroke_value as Dictionary).duplicate(true)
			var shuffled_points: Array = (shuffled_stroke.get("points", []) as Array).duplicate(true)
			for index: int in range(shuffled_points.size() - 1, 0, -1):
				var swap_index := rng.randi_range(0, index)
				var swap_value: Variant = shuffled_points[index]
				shuffled_points[index] = shuffled_points[swap_index]
				shuffled_points[swap_index] = swap_value
			shuffled_stroke["points"] = shuffled_points
			shuffled_strokes.append(shuffled_stroke)
		mean_score += _motif_recurrence(shuffled_strokes)
	return mean_score / float(SHUFFLE_REPLICATES)


func _new_surface() -> Variant:
	return _surface_script.new()


func _current_family_record(world: Node3D, version: int) -> Dictionary:
	var saved_norns := {}
	var actor_ids: Array = world.call("ordered_profile_ids")
	for actor_id_value: Variant in actor_ids:
		var actor_id := str(actor_id_value)
		var profile: Variant = world.call("profile_for", actor_id)
		saved_norns[actor_id] = world.call("_serialize_profile", profile)
	return {
		"version": version,
		"seed": 4181996,
		"simulationTime": float(world.get("simulation_time")),
		"focusedNornId": str(world.get("focused_norn_id")),
		"nextNornNumber": int(world.get("next_norn_number")),
		"norns": saved_norns,
		"eggs": (world.get("eggs") as Array).duplicate(true)
	}


func _maximum_surface_state() -> Dictionary:
	var strokes: Array[Dictionary] = []
	var cursors: Array[Dictionary] = [
		{"actorId": "mallow", "x": 128, "y": 128},
		{"actorId": "moss", "x": 128, "y": 128},
		{"actorId": "norn-1", "x": 128, "y": 128},
		{"actorId": "norn-2", "x": 128, "y": 128}
	]
	for stroke_index: int in range(MAX_STROKES):
		var points: Array[Dictionary] = []
		for point_index: int in range(MAX_POINTS_PER_STROKE):
			points.append({"x": 128, "y": 128, "pressure": 128})
		strokes.append({"actorId": "mallow", "active": false, "points": points})
	return {"version": 1, "strokes": strokes, "cursors": cursors}


func _sum_grid(grid: PackedFloat32Array) -> float:
	var total := 0.0
	for value: float in grid:
		total += value
	return total


func _sensed_has(entries: Array, object_id: String) -> bool:
	for entry: Variant in entries:
		if entry is Dictionary and str(entry.get("id", "")) == object_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("DRAWING_SLICE_CHECKS_OK cases=surface,perception,motor,effector,eligibility,safety,incremental-outcome,save-schema")
		quit(0)
		return
	for failure: String in _failures:
		push_error("DRAWING_SURFACE_CHECK_FAILED: " + failure)
	push_error("DRAWING_SURFACE_CHECKS_FAILED failures=%d" % _failures.size())
	quit(1)
