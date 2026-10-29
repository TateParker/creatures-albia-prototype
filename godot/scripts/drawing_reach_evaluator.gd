class_name DrawingReachEvaluator
extends RefCounted

const Cognition := preload("res://scripts/norn_cognition.gd")
const DrawingReachTask := preload("res://scripts/drawing_reach_task.gd")
const DrawingSurface := preload("res://scripts/drawing_surface.gd")

const DECISION_INTERVAL_SECONDS := 0.2
const DECISIONS_PER_TRIAL := 6
const TRIALS_PER_DIRECTION := 4
const ACTOR_ID := "reach-probe"
const DRAWING_SURFACE_ID := "drawing_surface"
const DRAW_TOOL_ID := "charcoal"


static func create_trial(seed: int, direction_index: int) -> Dictionary:
	var target_uv: Variant = DrawingReachTask.target_uv_for_direction(direction_index)
	if not (target_uv is Vector2):
		return {}
	var surface: RefCounted = DrawingSurface.new()
	if not surface.append_point(ACTOR_ID, DrawingReachTask.START_UV, 0.0, false):
		return {}
	var state: Dictionary = Cognition.create_state(seed)
	return {
		"seed": seed,
		"directionIndex": direction_index,
		"targetUv": target_uv,
		"surface": surface,
		"state": state,
		"stepCount": 0,
		"simulatedSeconds": 0.0,
		"complete": false,
		"failed": false,
		"finalUv": surface.get_last_uv(ACTOR_ID)
	}


static func advance_trial(trial: Dictionary) -> bool:
	if bool(trial.get("complete", false)):
		return true
	var surface_value: Variant = trial.get("surface", null)
	var state_value: Variant = trial.get("state", null)
	var target_value: Variant = trial.get("targetUv", null)
	if surface_value == null or not (state_value is Dictionary) or not (target_value is Vector2):
		return _fail_trial(trial, "Trial is missing its surface, cognition state, or target.")
	var surface: RefCounted = surface_value
	var state: Dictionary = state_value
	var cursor_uv: Vector2 = surface.get_last_uv(ACTOR_ID)
	var target_delta: Variant = DrawingReachTask.normalized_target_delta(cursor_uv, target_value)
	if not (target_delta is Vector2):
		return _fail_trial(trial, "Trial cursor or target is outside the task bounds.")
	var nearby_objects: Array[Dictionary] = [
		{"id": DRAWING_SURFACE_ID, "distance": 1.0},
		{"id": DRAW_TOOL_ID, "distance": 1.0}
	]
	var observation := {
		"chemistry": state["chemistry"],
		"nearbyObjects": nearby_objects,
		"surfaceMarks": surface.sample_mark_grid(cursor_uv, 16),
		"drawTargetDelta": target_delta
	}
	var command: Dictionary = Cognition.draw_motor_step(state, observation)
	if not _valid_motor_command(command):
		return _fail_trial(trial, "Cognition returned an invalid motor command.")
	var next_uv := Vector2(
		clampf(cursor_uv.x + float(command["dx"]), 0.0, 1.0),
		clampf(cursor_uv.y + float(command["dy"]), 0.0, 1.0)
	)
	if not surface.append_point(ACTOR_ID, next_uv, float(command["pressure"]), bool(command["contact"])):
		return _fail_trial(trial, "DrawingSurface rejected a motor command.")
	var step_count := int(trial.get("stepCount", 0)) + 1
	trial["stepCount"] = step_count
	trial["simulatedSeconds"] = float(step_count) * DECISION_INTERVAL_SECONDS
	trial["finalUv"] = surface.get_last_uv(ACTOR_ID)
	if step_count < DECISIONS_PER_TRIAL:
		return false
	var final_uv: Vector2 = trial["finalUv"]
	var score: Dictionary = DrawingReachTask.score_endpoint(final_uv, target_value)
	if score.is_empty():
		return _fail_trial(trial, "The final endpoint could not be scored.")
	trial["errorPixels"] = float(score["errorPixels"])
	trial["hit"] = bool(score["hit"])
	trial["decisionCount"] = int(state["decisionCount"])
	trial["complete"] = true
	return true


static func run_seed(seed: int) -> Dictionary:
	var directions: Array[int] = []
	for direction_index: int in range(DrawingReachTask.TARGET_COUNT):
		directions.append(direction_index)
	var schedule: Array[Dictionary] = DrawingReachTask.build_balanced_trial_order(directions, TRIALS_PER_DIRECTION, seed)
	if schedule.size() != DrawingReachTask.TARGET_COUNT * TRIALS_PER_DIRECTION:
		return {}
	var trial_results: Array[Dictionary] = []
	var endpoint_errors: Array[float] = []
	var hit_count := 0
	for scheduled_trial: Dictionary in schedule:
		var trial := create_trial(seed, int(scheduled_trial["directionIndex"]))
		if trial.is_empty():
			return {}
		trial["repeatIndex"] = int(scheduled_trial["repeatIndex"])
		for _decision_index: int in range(DECISIONS_PER_TRIAL):
			advance_trial(trial)
			if bool(trial.get("failed", false)):
				return {}
		if not bool(trial.get("complete", false)):
			return {}
		endpoint_errors.append(float(trial["errorPixels"]))
		if bool(trial["hit"]):
			hit_count += 1
		trial_results.append({
			"directionIndex": int(trial["directionIndex"]),
			"repeatIndex": int(trial["repeatIndex"]),
			"targetUv": trial["targetUv"],
			"finalUv": trial["finalUv"],
			"decisionCount": int(trial["decisionCount"]),
			"simulatedSeconds": float(trial["simulatedSeconds"]),
			"errorPixels": float(trial["errorPixels"]),
			"hit": bool(trial["hit"])
		})
	return {
		"seed": seed,
		"trialCount": trial_results.size(),
		"medianErrorPixels": _median(endpoint_errors),
		"hitRate": float(hit_count) / float(trial_results.size()),
		"trials": trial_results
	}


static func run_baseline(seeds: Array[int]) -> Dictionary:
	if seeds.is_empty():
		return {}
	var seen_seeds := {}
	var seed_results: Array[Dictionary] = []
	var seed_median_errors: Array[float] = []
	var seed_hit_rates: Array[float] = []
	for seed: int in seeds:
		if seed < 0 or seen_seeds.has(seed):
			return {}
		seen_seeds[seed] = true
		var seed_result := run_seed(seed)
		if seed_result.is_empty():
			return {}
		seed_results.append(seed_result)
		seed_median_errors.append(float(seed_result["medianErrorPixels"]))
		seed_hit_rates.append(float(seed_result["hitRate"]))
	return {
		"seeds": seed_results,
		"seedCount": seed_results.size(),
		"trialsPerSeed": DrawingReachTask.TARGET_COUNT * TRIALS_PER_DIRECTION,
		"medianErrorPixels": _median(seed_median_errors),
		"medianHitRate": _median(seed_hit_rates)
	}


static func _valid_motor_command(command: Dictionary) -> bool:
	for field: String in ["dx", "dy", "pressure"]:
		var value: Variant = command.get(field, null)
		if not (value is float or value is int) or not is_finite(float(value)):
			return false
	if not (command.get("contact", null) is bool):
		return false
	return absf(float(command["dx"])) <= 0.08 and absf(float(command["dy"])) <= 0.08 and float(command["pressure"]) >= 0.05 and float(command["pressure"]) <= 0.85


static func _fail_trial(trial: Dictionary, message: String) -> bool:
	trial["failed"] = true
	trial["failureReason"] = message
	trial["complete"] = true
	return true


static func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var ordered := values.duplicate()
	ordered.sort()
	var midpoint := ordered.size() / 2
	if ordered.size() % 2 == 1:
		return ordered[midpoint]
	return (ordered[midpoint - 1] + ordered[midpoint]) * 0.5
