extends SceneTree

const Cognition := preload("res://scripts/norn_cognition.gd")
const INPUT_COUNT := 278
const MARK_INPUT_START := 20
const MARK_INPUT_COUNT := 256
const TARGET_INPUT_START := 276
const TASK_SCRIPT_PATH := "res://scripts/drawing_reach_task.gd"
const EVALUATOR_SCRIPT_PATH := "res://scripts/drawing_reach_evaluator.gd"
const PREVIEW_SCENE_PATH := "res://tools/drawing_reach_preview.tscn"

var _failures: Array[String] = []
var _task_script: Script
var _evaluator_script: Script


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	_task_script = load(TASK_SCRIPT_PATH) as Script
	_evaluator_script = load(EVALUATOR_SCRIPT_PATH) as Script
	test_target_delta_appends_after_mark_input()
	test_missing_or_hidden_target_delta_defaults_to_zero()
	test_target_delta_is_bounded()
	test_target_free_motor_matches_v3_reference()
	test_draw_motor_step_advances_once()
	test_cognition_versions_1_through_3_migrate_to_4()
	test_eight_target_points_are_in_bounds()
	test_invalid_direction_is_rejected()
	test_balanced_order_respects_requested_directions()
	test_trial_order_is_seed_deterministic()
	test_target_delta_tracks_quantized_cursor()
	test_endpoint_error_uses_255_pixel_scale()
	test_eight_pixel_hit_boundary_is_inclusive()
	test_each_seed_runs_32_balanced_trials()
	test_trial_resets_cursor_surface_and_hidden_state()
	test_each_trial_uses_exactly_six_steps()
	test_baseline_does_not_update_reward_or_associations()
	test_seed_replay_reproduces_endpoints()
	test_five_seed_aggregate_reports_medians()
	test_preview_scene_is_standalone()
	if _failures.is_empty():
		print("DRAWING_REACH_CHECKS_OK cognition=true task=true evaluator=true baseline=5x32 preview=true")
		quit()
		return
	for failure: String in _failures:
		push_error("DRAWING_REACH_CHECK_FAILED: " + failure)
	quit(1)


func test_target_delta_appends_after_mark_input() -> void:
	var state: Dictionary = Cognition.create_state(8801)
	var marks := PackedFloat32Array()
	marks.resize(MARK_INPUT_COUNT)
	for index: int in range(MARK_INPUT_COUNT):
		marks[index] = float(index) / float(MARK_INPUT_COUNT - 1)
	var visible_objects: Array[Dictionary] = [
		{"id": "drawing_surface", "distance": 4.0},
		{"id": "charcoal", "distance": 2.0}
	]
	var input: Array[float] = Cognition._get_input_vector(state, {
		"nearbyObjects": visible_objects,
		"surfaceMarks": marks,
		"drawTargetDelta": Vector2(0.375, -0.625)
	})
	_expect(input.size() == INPUT_COUNT, "cognition input contains 20 named signals, 256 marks, and 2 reach cues")
	if input.size() == INPUT_COUNT:
		_expect(is_equal_approx(input[MARK_INPUT_START], marks[0]), "first mark remains at input 20")
		_expect(is_equal_approx(input[MARK_INPUT_START + MARK_INPUT_COUNT - 1], marks[MARK_INPUT_COUNT - 1]), "last mark remains at input 275")
		_expect(is_equal_approx(input[TARGET_INPUT_START], 0.375) and is_equal_approx(input[TARGET_INPUT_START + 1], -0.625), "target cues occupy only inputs 276 and 277")


func test_missing_or_hidden_target_delta_defaults_to_zero() -> void:
	var state: Dictionary = Cognition.create_state(8802)
	var visible_objects: Array[Dictionary] = [
		{"id": "drawing_surface"},
		{"id": "charcoal"}
	]
	var observations: Array[Dictionary] = [
		{"nearbyObjects": visible_objects},
		{"nearbyObjects": visible_objects, "drawTargetDelta": "0.5,0.5"},
		{"nearbyObjects": visible_objects, "drawTargetDelta": Vector2(INF, 0.5)},
		{"nearbyObjects": [{"id": "drawing_surface"}], "drawTargetDelta": Vector2(0.5, 0.5)},
		{"nearbyObjects": [{"id": "charcoal"}], "drawTargetDelta": Vector2(0.5, 0.5)},
		{"nearbyObjects": [], "drawTargetDelta": Vector2(0.5, 0.5)}
	]
	for observation: Dictionary in observations:
		var input: Array[float] = Cognition._get_input_vector(state, observation)
		_expect(input.size() == INPUT_COUNT, "every observation yields 278 cognition inputs")
		if input.size() == INPUT_COUNT:
			_expect(is_zero_approx(input[TARGET_INPUT_START]) and is_zero_approx(input[TARGET_INPUT_START + 1]), "missing, malformed, non-finite, or hidden target cues append zeros")


func test_target_delta_is_bounded() -> void:
	var state: Dictionary = Cognition.create_state(8803)
	var visible_objects: Array[Dictionary] = [
		{"id": "drawing_surface"},
		{"id": "charcoal"}
	]
	var input: Array[float] = Cognition._get_input_vector(state, {
		"nearbyObjects": visible_objects,
		"drawTargetDelta": Vector2(1.25, -1.75)
	})
	_expect(input.size() == INPUT_COUNT, "bounded target input keeps the 278-value width")
	if input.size() == INPUT_COUNT:
		_expect(is_equal_approx(input[TARGET_INPUT_START], 1.0) and is_equal_approx(input[TARGET_INPUT_START + 1], -1.0), "finite target cue components clamp to the normalized range")


func test_target_free_motor_matches_v3_reference() -> void:
	var expected: Dictionary = {
		903: [
			Vector4(0.00762725949287415, 0.0129664659500122, 0.500305682420731, 1.0),
			Vector4(0.00545491695404053, 0.014580135345459, 0.498781698942184, 1.0),
			Vector4(0.00513487577438354, 0.0143372964859009, 0.500232356786728, 1.0),
			Vector4(0.00514484643936157, 0.0143091559410095, 0.500171500444412, 1.0),
			Vector4(0.00517516851425171, 0.0143035316467285, 0.500141924619675, 1.0),
			Vector4(0.00517829239368439, 0.0142963862419128, 0.5001384973526, 1.0)
		],
		9901: [
			Vector4(0.00245138764381409, -0.00420246034860611, 0.490075179934502, 1.0),
			Vector4(0.00149774223566055, -0.00333068042993546, 0.487694522738457, 0.0),
			Vector4(0.00155675396323204, -0.00329236775636673, 0.489393800497055, 1.0),
			Vector4(0.00154372960329056, -0.00333510458469391, 0.489172038435936, 1.0),
			Vector4(0.00153459385037422, -0.00335516005754471, 0.489142653346062, 1.0),
			Vector4(0.00153166472911835, -0.00335659980773926, 0.489125227928162, 1.0)
		]
	}
	for seed_value: int in [903, 9901]:
		var commands: Array[Dictionary] = _target_free_commands(seed_value)
		var fixtures: Array = expected[seed_value]
		_expect(commands.size() == fixtures.size(), "v3 compatibility fixture has six decisions for seed %d" % seed_value)
		for index: int in range(mini(commands.size(), fixtures.size())):
			var command: Dictionary = commands[index]
			var fixture: Vector4 = fixtures[index]
			_expect(
				absf(float(command["dx"]) - fixture.x) <= 0.000001
				and absf(float(command["dy"]) - fixture.y) <= 0.000001
				and absf(float(command["pressure"]) - fixture.z) <= 0.000001
				and (1.0 if bool(command["contact"]) else 0.0) == fixture.w,
				"target-free motor command %d matches cognition v3 for seed %d" % [index, seed_value]
			)


func test_draw_motor_step_advances_once() -> void:
	var state: Dictionary = Cognition.create_state(8804)
	var step_method := Callable(Cognition, "draw_motor_step")
	_expect(step_method.is_valid(), "cognition exposes draw_motor_step")
	if not step_method.is_valid():
		return
	var before_count := int(state["decisionCount"])
	var before_hidden: PackedFloat32Array = state["hidden"].duplicate()
	var command: Variant = step_method.call(state, {"chemistry": state["chemistry"]})
	_expect(command is Dictionary and command.has("dx") and command.has("dy"), "draw_motor_step returns the bounded motor command")
	_expect(int(state["decisionCount"]) == before_count + 1, "draw_motor_step advances recurrence once")
	_expect(state["hidden"] != before_hidden, "draw_motor_step updates recurrent state")


func test_cognition_versions_1_through_3_migrate_to_4() -> void:
	var source: Dictionary = Cognition.create_state(8805)
	source["actionAssociations"]["fruit"] = 0.73
	source["actionAssociations"]["draw"] = 0.77
	source["chemistry"]["hunger"] = 37.0
	source["hidden"][0] = 0.25
	source["decisionCount"] = 7
	Cognition.record_outcome(source, {"eventType": "experience", "actionId": "idle", "reward": 0.0})
	Cognition.decide(source, {"chemistry": source["chemistry"]})
	source["hidden"][0] = 0.25
	source["decisionCount"] = 7
	var source_record: Dictionary = Cognition.serialize_state(source)
	for source_version: int in [1, 2, 3]:
		var record: Dictionary = source_record.duplicate(true)
		record["version"] = source_version
		if source_version < 3:
			record["actionAssociations"].erase("draw")
			record["contextAssociations"].erase("draw")
			record["eligibility"].erase("draw")
			record["contextEligibility"].erase("draw")
			record["lastDecision"]["actionScores"].erase("draw")
			record["lastDecision"]["components"].erase("drawNeed")
		var restored: Dictionary = Cognition.restore_state(record)
		_expect(not restored.is_empty(), "cognition version %d restores" % source_version)
		if restored.is_empty():
			continue
		_expect(int(restored["version"]) == 4, "cognition version %d migrates to version 4" % source_version)
		var expected_fruit := 0.865 if source_version == 1 else 0.73
		_expect(is_equal_approx(float(restored["actionAssociations"]["fruit"]), expected_fruit), "cognition version %d preserves or maps action associations" % source_version)
		_expect(is_equal_approx(float(restored["chemistry"]["hunger"]), 37.0), "cognition version %d preserves chemistry" % source_version)
		_expect(is_equal_approx(float(restored["hidden"][0]), 0.25) and int(restored["decisionCount"]) == 7, "cognition version %d preserves recurrent state" % source_version)
		_expect((restored["episodes"] as Array).size() == 1 and int(restored["episodes"][0]["id"]) == 1, "cognition version %d preserves episodes" % source_version)
		var restored_scores: Dictionary = restored["lastDecision"].get("actionScores", {})
		var restored_components: Dictionary = restored["lastDecision"].get("components", {})
		var expected_draw_score := float(source_record["lastDecision"]["actionScores"]["draw"]) if source_version == 3 else 0.0
		var expected_draw_need := float(source_record["lastDecision"]["components"]["drawNeed"]) if source_version == 3 else 0.0
		_expect(is_equal_approx(float(restored_scores.get("draw", -1.0)), expected_draw_score), "cognition version %d preserves the historical draw score" % source_version)
		_expect(is_equal_approx(float(restored_components.get("drawNeed", -1.0)), expected_draw_need), "cognition version %d preserves the historical draw need" % source_version)
		if source_version == 3:
			_expect(is_equal_approx(float(restored["actionAssociations"]["draw"]), 0.77), "version-3 draw association survives cognition migration")


func test_eight_target_points_are_in_bounds() -> void:
	var target_method := _task_method("target_uv_for_direction")
	_expect(_task_script != null and target_method.is_valid(), "reach task exposes target geometry")
	if not target_method.is_valid():
		return
	for direction_index: int in range(8):
		var target: Variant = target_method.call(direction_index)
		var expected := Vector2(0.5, 0.5) + Vector2.RIGHT.rotated(TAU * float(direction_index) / 8.0) * 0.24
		_expect(target is Vector2 and (target as Vector2).distance_to(expected) <= 0.000001, "direction %d maps to its clockwise radius-0.24 target" % direction_index)
		_expect(target is Vector2 and target.x >= 0.0 and target.x <= 1.0 and target.y >= 0.0 and target.y <= 1.0, "direction %d target remains on the surface" % direction_index)


func test_invalid_direction_is_rejected() -> void:
	var target_method := _task_method("target_uv_for_direction")
	if not target_method.is_valid():
		return
	_expect(target_method.call(-1) == null and target_method.call(8) == null, "out-of-range target directions are rejected")
	var delta_method := _task_method("normalized_target_delta")
	if delta_method.is_valid():
		_expect(delta_method.call(Vector2(-0.01, 0.5), Vector2(0.5, 0.5)) == null, "out-of-bounds cursors are rejected")
		_expect(delta_method.call(Vector2(0.5, 0.5), Vector2(NAN, 0.5)) == null, "non-finite targets are rejected")
	else:
		_expect(false, "reach task exposes target delta validation")
	var schedule_method := _task_method("build_balanced_trial_order")
	if schedule_method.is_valid():
		var empty_directions: Array[int] = []
		var duplicate_directions: Array[int] = [0, 0]
		var invalid_directions: Array[int] = [0, 8]
		var single_direction: Array[int] = [0]
		_expect((schedule_method.call(empty_directions, 4, 11) as Array).is_empty(), "empty direction lists are rejected")
		_expect((schedule_method.call(duplicate_directions, 4, 11) as Array).is_empty(), "duplicate directions are rejected")
		_expect((schedule_method.call(invalid_directions, 4, 11) as Array).is_empty(), "invalid scheduled directions are rejected")
		_expect((schedule_method.call(single_direction, 0, 11) as Array).is_empty(), "non-positive repetition counts are rejected")
	else:
		_expect(false, "reach task exposes balanced trial scheduling")
	var score_method := _task_method("score_endpoint")
	if score_method.is_valid():
		_expect((score_method.call(Vector2(1.01, 0.5), Vector2(0.5, 0.5)) as Dictionary).is_empty(), "out-of-bounds final cursors are rejected")
	else:
		_expect(false, "reach task exposes endpoint scoring")


func test_balanced_order_respects_requested_directions() -> void:
	var schedule_method := _task_method("build_balanced_trial_order")
	_expect(schedule_method.is_valid(), "reach task exposes balanced scheduling")
	if not schedule_method.is_valid():
		return
	var directions: Array[int] = [0, 2, 4, 6]
	var schedule_value: Variant = schedule_method.call(directions, 4, 9901)
	_expect(schedule_value is Array and (schedule_value as Array).size() == 16, "four requested directions repeated four times produce 16 trials")
	if not (schedule_value is Array):
		return
	var schedule: Array = schedule_value
	var counts := {}
	for entry_value: Variant in schedule:
		_expect(entry_value is Dictionary, "trial entries are dictionaries")
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var direction_index := int(entry.get("directionIndex", -1))
		counts[direction_index] = int(counts.get(direction_index, 0)) + 1
		_expect(directions.has(direction_index), "schedule contains only requested directions")
		_expect(int(entry.get("repeatIndex", -1)) >= 0 and int(entry.get("repeatIndex", 99)) < 4, "repeat index is inside the requested repeat count")
		_expect(entry.get("targetUv", null) is Vector2, "every trial contains its target UV")
	_expect(counts.size() == directions.size(), "every requested direction appears")
	for direction_index: int in directions:
		_expect(int(counts.get(direction_index, 0)) == 4, "direction %d has four balanced trials" % direction_index)


func test_trial_order_is_seed_deterministic() -> void:
	var schedule_method := _task_method("build_balanced_trial_order")
	if not schedule_method.is_valid():
		return
	var directions: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7]
	var first: Variant = schedule_method.call(directions, 4, 4321)
	var replay: Variant = schedule_method.call(directions, 4, 4321)
	var other_seed: Variant = schedule_method.call(directions, 4, 4322)
	_expect(first is Array and replay is Array and first == replay, "equal schedule seeds reproduce the same ordered trial entries")
	_expect(first is Array and other_seed is Array and first != other_seed, "different schedule seeds produce different orders")


func test_target_delta_tracks_quantized_cursor() -> void:
	var delta_method := _task_method("normalized_target_delta")
	_expect(delta_method.is_valid(), "reach task exposes normalized target deltas")
	if not delta_method.is_valid():
		return
	var center := Vector2(128.0 / 255.0, 128.0 / 255.0)
	var delta: Variant = delta_method.call(center, Vector2(0.74, 0.5))
	_expect(delta is Vector2 and (delta as Vector2).distance_to(Vector2((0.74 - center.x) / 0.25, (0.5 - center.y) / 0.25)) <= 0.000001, "delta uses the quantized cursor and 0.25-UV normalization")
	var bounded: Variant = delta_method.call(Vector2.ZERO, Vector2.ONE)
	_expect(bounded is Vector2 and bounded == Vector2.ONE, "normalized target deltas clamp each component")


func test_endpoint_error_uses_255_pixel_scale() -> void:
	var score_method := _task_method("score_endpoint")
	_expect(score_method.is_valid(), "reach task exposes endpoint scoring")
	if not score_method.is_valid():
		return
	var score: Variant = score_method.call(Vector2(0.6, 0.5), Vector2(0.61, 0.5))
	_expect(score is Dictionary and is_equal_approx(float((score as Dictionary).get("errorPixels", -1.0)), Vector2(0.6, 0.5).distance_to(Vector2(0.61, 0.5)) * 255.0), "endpoint error uses 255 pixel intervals")
	var center_score: Variant = score_method.call(Vector2(0.5, 0.5), Vector2(0.5, 0.5))
	_expect(center_score is Dictionary and is_zero_approx(float((center_score as Dictionary).get("errorPixels", -1.0))), "an exact endpoint has zero pixel error")


func test_eight_pixel_hit_boundary_is_inclusive() -> void:
	var score_method := _task_method("score_endpoint")
	if not score_method.is_valid():
		return
	var boundary: Variant = score_method.call(Vector2(0.5 + 8.0 / 255.0, 0.5), Vector2(0.5, 0.5))
	var outside: Variant = score_method.call(Vector2(0.5 + 8.01 / 255.0, 0.5), Vector2(0.5, 0.5))
	_expect(boundary is Dictionary and is_equal_approx(float((boundary as Dictionary).get("errorPixels", -1.0)), 8.0), "8-pixel boundary is measured inclusively")
	_expect(boundary is Dictionary and bool((boundary as Dictionary).get("hit", false)), "endpoint exactly 8 pixels away is a hit")
	_expect(outside is Dictionary and not bool((outside as Dictionary).get("hit", true)), "endpoint beyond 8 pixels is not a hit")


func test_each_seed_runs_32_balanced_trials() -> void:
	var run_method := _evaluator_method("run_seed")
	_expect(_evaluator_script != null and run_method.is_valid(), "reach evaluator exposes a per-seed runner")
	if not run_method.is_valid():
		return
	var result: Variant = run_method.call(9901)
	_expect(result is Dictionary, "per-seed evaluation returns a result dictionary")
	if not (result is Dictionary):
		return
	var trials: Array = result.get("trials", [])
	_expect(trials.size() == 32, "one seed runs exactly 32 balanced target trials")
	var counts := {}
	for trial_value: Variant in trials:
		if not (trial_value is Dictionary):
			_expect(false, "evaluation trial result is a dictionary")
			continue
		var trial: Dictionary = trial_value
		var direction_index := int(trial.get("directionIndex", -1))
		counts[direction_index] = int(counts.get(direction_index, 0)) + 1
		_expect(int(trial.get("decisionCount", -1)) == 6, "each target trial uses six motor decisions")
		_expect(is_equal_approx(float(trial.get("simulatedSeconds", -1.0)), 1.2), "six decisions span 1.2 simulated seconds")
		_expect(trial.get("finalUv", null) is Vector2, "trial result stores the quantized final cursor")
		_expect(trial.has("errorPixels") and trial.has("hit"), "trial result stores endpoint score and hit")
	_expect(counts.size() == 8, "baseline includes all eight target directions")
	for direction_index: int in range(8):
		_expect(int(counts.get(direction_index, 0)) == 4, "direction %d occurs four times per seed" % direction_index)
	_expect(int(result.get("trialCount", -1)) == 32, "per-seed result reports its full trial count")
	_expect(result.has("medianErrorPixels") and result.has("hitRate"), "per-seed result reports median error and hit rate")


func test_trial_resets_cursor_surface_and_hidden_state() -> void:
	var create_method := _evaluator_method("create_trial")
	_expect(create_method.is_valid(), "reach evaluator exposes clean trial creation")
	if not create_method.is_valid():
		return
	var first: Variant = create_method.call(9901, 0)
	_expect(first is Dictionary, "trial creation returns a state dictionary")
	if not (first is Dictionary):
		return
	var first_surface: Variant = first.get("surface", null)
	var first_state: Dictionary = first.get("state", {})
	if first_surface == null or first_state.is_empty():
		_expect(false, "trial contains its isolated surface and cognition state")
		return
	first_surface.append_point("reach-probe", Vector2(0.7, 0.6), 0.5, true)
	first_state["hidden"][0] = 0.9
	first_state["decisionCount"] = 4
	var second: Variant = create_method.call(9901, 0)
	_expect(second is Dictionary, "second trial is independently created")
	if not (second is Dictionary):
		return
	var second_surface: Variant = second.get("surface", null)
	var second_state: Dictionary = second.get("state", {})
	var center := Vector2(128.0 / 255.0, 128.0 / 255.0)
	_expect(second_surface != first_surface, "each trial receives a fresh drawing surface")
	_expect(second_surface.get_stroke_count() == 0, "new trial surface starts without marks")
	_expect(second_surface.get_last_uv("reach-probe").distance_to(center) <= 0.000001, "new trial persists the quantized center cursor")
	_expect(int(second_state.get("decisionCount", -1)) == 0, "new trial resets its decision count")
	var hidden: PackedFloat32Array = second_state.get("hidden", PackedFloat32Array())
	var hidden_zero := true
	for value: float in hidden:
		hidden_zero = hidden_zero and is_zero_approx(value)
	_expect(hidden.size() == 128 and hidden_zero, "new trial resets all recurrent hidden units")


func test_each_trial_uses_exactly_six_steps() -> void:
	var create_method := _evaluator_method("create_trial")
	var advance_method := _evaluator_method("advance_trial")
	_expect(create_method.is_valid() and advance_method.is_valid(), "reach evaluator exposes creation and single-step advancement")
	if not create_method.is_valid() or not advance_method.is_valid():
		return
	var trial: Variant = create_method.call(9902, 2)
	if not (trial is Dictionary):
		_expect(false, "trial creation returns a mutable trial dictionary")
		return
	for step_index: int in range(6):
		var complete: Variant = advance_method.call(trial)
		_expect(bool(complete) == (step_index == 5), "trial completes exactly after decision %d" % (step_index + 1))
	_expect(int(trial.get("stepCount", -1)) == 6, "trial records six completed steps")
	_expect(int(trial["state"].get("decisionCount", -1)) == 6, "cognition advances once per trial step")
	_expect(is_equal_approx(float(trial.get("simulatedSeconds", -1.0)), 1.2), "trial duration is six times 0.2 seconds")
	var final_cursor: Vector2 = trial["surface"].get_last_uv("reach-probe")
	_expect(trial.get("finalUv", Vector2.ZERO) == final_cursor, "trial grades the persisted quantized cursor")
	_expect(bool(advance_method.call(trial)) and int(trial.get("stepCount", -1)) == 6, "completed trial does not advance a seventh time")


func test_baseline_does_not_update_reward_or_associations() -> void:
	var create_method := _evaluator_method("create_trial")
	var advance_method := _evaluator_method("advance_trial")
	if not create_method.is_valid() or not advance_method.is_valid():
		return
	var trial: Variant = create_method.call(9903, 4)
	if not (trial is Dictionary):
		_expect(false, "trial can be created for no-update assertions")
		return
	var state: Dictionary = trial["state"]
	var associations: Dictionary = state["actionAssociations"].duplicate(true)
	var context_associations: Dictionary = state["contextAssociations"].duplicate(true)
	var episodes: Array = state["episodes"].duplicate(true)
	var motor_weights: PackedFloat32Array = state["policy"]["motorWeights"].duplicate()
	var motor_biases: PackedFloat32Array = state["policy"]["motorBiases"].duplicate()
	for step_index: int in range(6):
		advance_method.call(trial)
	_expect(state["actionAssociations"] == associations, "baseline does not change action associations")
	_expect(state["contextAssociations"] == context_associations, "baseline does not change context associations")
	_expect(state["episodes"] == episodes, "baseline does not add outcome or reward episodes")
	_expect(state["policy"]["motorWeights"] == motor_weights, "baseline does not update motor weights")
	_expect(state["policy"]["motorBiases"] == motor_biases, "baseline does not update motor biases")


func test_seed_replay_reproduces_endpoints() -> void:
	var run_method := _evaluator_method("run_seed")
	if not run_method.is_valid():
		return
	var first: Variant = run_method.call(9901)
	var replay: Variant = run_method.call(9901)
	_expect(first is Dictionary and replay is Dictionary, "replay runs return result dictionaries")
	if first is Dictionary and replay is Dictionary:
		_expect(first.get("trials", []) == replay.get("trials", []), "equal seeds reproduce order, endpoints, errors, and hit flags")


func test_five_seed_aggregate_reports_medians() -> void:
	var baseline_method := _evaluator_method("run_baseline")
	_expect(baseline_method.is_valid(), "reach evaluator exposes the five-seed baseline")
	if not baseline_method.is_valid():
		return
	var seeds: Array[int] = [9901, 9902, 9903, 9904, 9905]
	var baseline: Variant = baseline_method.call(seeds)
	_expect(baseline is Dictionary, "baseline aggregation returns a result dictionary")
	if not (baseline is Dictionary):
		return
	var seed_rows: Array = baseline.get("seeds", [])
	_expect(seed_rows.size() == 5, "baseline returns one result for each fixed seed")
	var errors: Array[float] = []
	var hit_rates: Array[float] = []
	for index: int in range(mini(5, seed_rows.size())):
		var row: Dictionary = seed_rows[index]
		_expect(int(row.get("seed", -1)) == seeds[index], "baseline rows preserve the fixed seed order")
		_expect(int(row.get("trialCount", -1)) == 32, "each fixed seed has 32 trials")
		errors.append(float(row.get("medianErrorPixels", -1.0)))
		hit_rates.append(float(row.get("hitRate", -1.0)))
	_expect(is_equal_approx(float(baseline.get("medianErrorPixels", -1.0)), _median_for_test(errors)), "across-seed endpoint error is the median of seed-level medians")
	_expect(is_equal_approx(float(baseline.get("medianHitRate", -1.0)), _median_for_test(hit_rates)), "across-seed hit rate is the median of seed-level hit rates")


func test_preview_scene_is_standalone() -> void:
	var preview_scene: Variant = load(PREVIEW_SCENE_PATH)
	_expect(preview_scene is PackedScene, "reach preview scene loads")
	if not (preview_scene is PackedScene):
		return
	var preview: Node = (preview_scene as PackedScene).instantiate()
	_expect(preview is Control, "reach preview is a standalone rendered control scene")
	_expect(preview.get_script() != null, "reach preview scene has its own capture script")
	_expect(not preview.has_node("Albia"), "reach preview does not instantiate the shared habitat")
	preview.free()


func _target_free_commands(seed: int) -> Array[Dictionary]:
	var state: Dictionary = Cognition.create_state(seed)
	var marks := PackedFloat32Array()
	marks.resize(MARK_INPUT_COUNT)
	marks.fill(0.0)
	var observation := {
		"chemistry": state["chemistry"],
		"nearbyObjects": [{"id": "drawing_surface"}, {"id": "charcoal"}],
		"surfaceMarks": marks
	}
	var commands: Array[Dictionary] = []
	for decision_index: int in range(6):
		Cognition._update_recurrent_state(state, observation)
		commands.append(Cognition.draw_motor_command(state))
	return commands


func _task_method(method_name: String) -> Callable:
	return Callable(_task_script, method_name) if _task_script != null else Callable()


func _evaluator_method(method_name: String) -> Callable:
	return Callable(_evaluator_script, method_name) if _evaluator_script != null else Callable()


func _median_for_test(values: Array[float]) -> float:
	var ordered := values.duplicate()
	ordered.sort()
	if ordered.is_empty():
		return 0.0
	var midpoint := ordered.size() / 2
	if ordered.size() % 2 == 1:
		return ordered[midpoint]
	return (ordered[midpoint - 1] + ordered[midpoint]) * 0.5


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
