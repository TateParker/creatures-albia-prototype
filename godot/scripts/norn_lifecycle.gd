class_name NornLifecycle
extends RefCounted

const MIN_LIFESPAN_SECONDS := 3300.0
const MAX_LIFESPAN_SECONDS := 3900.0
const BABY_END_SECONDS := 60.0
const CHILD_END_SECONDS := 180.0
const ADOLESCENT_END_SECONDS := 420.0
const ADULT_END_SECONDS := 3000.0
const MAX_COGNITION_SEED := 0xffffffff


static func create_state(seed: int, age_seconds: float = 0.0) -> Dictionary:
	if seed < 0 or seed > MAX_COGNITION_SEED or not _is_finite_number(age_seconds) or age_seconds < 0.0:
		return {}
	var lifespan_seconds := 3600.0 + float(posmod(seed, 601)) - 300.0
	if age_seconds >= lifespan_seconds:
		return {}
	return {
		"ageSeconds": age_seconds,
		"lifespanSeconds": lifespan_seconds,
		"alive": true,
		"death": {}
	}


static func stage_for_age(age_seconds: float) -> String:
	if not _is_finite_number(age_seconds) or age_seconds < 0.0:
		return ""
	if age_seconds < BABY_END_SECONDS:
		return "baby"
	if age_seconds < CHILD_END_SECONDS:
		return "child"
	if age_seconds < ADOLESCENT_END_SECONDS:
		return "adolescent"
	if age_seconds < ADULT_END_SECONDS:
		return "adult"
	return "elder"


static func advance(state: Dictionary, delta_seconds: float, simulation_time: float) -> Dictionary:
	if not _is_valid_state(state) or not _is_finite_number(delta_seconds) or delta_seconds < 0.0 or not _is_finite_number(simulation_time) or simulation_time < 0.0:
		return _result(false, false, "", "", false)
	var previous_stage := stage_for_age(float(state["ageSeconds"]))
	if not bool(state["alive"]):
		return _result(true, false, previous_stage, previous_stage, false)
	var next_age := float(state["ageSeconds"]) + delta_seconds
	if not is_finite(next_age):
		return _result(false, false, previous_stage, previous_stage, false)
	var died := next_age >= float(state["lifespanSeconds"])
	if died:
		next_age = float(state["lifespanSeconds"])
	state["ageSeconds"] = next_age
	if died:
		state["alive"] = false
		state["death"] = {
			"cause": "old-age",
			"ageSeconds": next_age,
			"simulationTime": simulation_time
		}
	var current_stage := stage_for_age(next_age)
	return _result(true, previous_stage != current_stage, previous_stage, current_stage, died)


static func serialize_state(state: Dictionary) -> Dictionary:
	if not _is_valid_state(state):
		return {}
	return state.duplicate(true)


static func restore_state(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var state: Dictionary = value
	if not _is_valid_state(state):
		return {}
	return state.duplicate(true)


static func _result(ok: bool, stage_changed: bool, previous_stage: String, stage: String, died: bool) -> Dictionary:
	return {
		"ok": ok,
		"stageChanged": stage_changed,
		"previousStage": previous_stage,
		"stage": stage,
		"died": died
	}


static func _is_valid_state(state: Dictionary) -> bool:
	if state.size() != 4:
		return false
	var age_value = state.get("ageSeconds", null)
	var lifespan_value = state.get("lifespanSeconds", null)
	var alive_value = state.get("alive", null)
	var death_value = state.get("death", null)
	if not _is_finite_number(age_value) or not _is_finite_number(lifespan_value) or typeof(alive_value) != TYPE_BOOL or not (death_value is Dictionary):
		return false
	var age := float(age_value)
	var lifespan := float(lifespan_value)
	if age < 0.0 or lifespan < MIN_LIFESPAN_SECONDS or lifespan > MAX_LIFESPAN_SECONDS or age > lifespan:
		return false
	var death: Dictionary = death_value
	if bool(alive_value):
		return age < lifespan and death.is_empty()
	if death.size() != 3 or str(death.get("cause", "")) != "old-age":
		return false
	var death_age = death.get("ageSeconds", null)
	var death_time = death.get("simulationTime", null)
	return _is_finite_number(death_age) and _is_finite_number(death_time) and float(death_age) >= 0.0 and is_equal_approx(float(death_age), lifespan) and is_equal_approx(age, lifespan) and float(death_time) >= 0.0


static func _is_finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))
