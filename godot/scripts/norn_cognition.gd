class_name NornCognition
extends RefCounted

const VERSION := 3
const EPISODE_LIMIT := 512
const RECURRENT_UNITS := 128
const RECURRENT_DEGREE := 4
const NAMED_INPUT_COUNT := 20
const MARK_INPUT_COUNT := 256
const INPUT_COUNT := NAMED_INPUT_COUNT + MARK_INPUT_COUNT
const MOTOR_OUTPUT_COUNT := 3
const DRAW_MAX_POINTS_PER_STROKE := 128
const PEER_SELECTION_RADIUS := 10.0
const ADOLESCENT_NON_PARENT_BONUS := 0.25
const PEER_MEMORY_SCORE_LIMIT := 0.35
const PEER_MEMORY_HALF_LIFE_SECONDS := 180.0
const PEER_MEMORY_FAMILIARITY_UNITS := 3.0
const ACTION_UTILITY_MIN := 0.0
const ACTION_UTILITY_MAX := 100.0
const ACTION_NON_DRIVE_LIMIT := 20.0
const FRUIT_URGENT_HUNGER := 90.0
const FRUIT_URGENT_GLUCOSE := 10.0
const REST_URGENT_FATIGUE := 95.0
const CHEMICAL_NAMES: Array[String] = [
	"glucose", "hunger", "curiosity", "fatigue", "reward",
	"punishment", "stress", "socialComfort", "arousal", "satiety"
]
const ACTION_IDS: Array[String] = ["fruit", "spinner", "rest", "observe_peer", "idle", "draw"]
const DRAW_SURFACE_ID := "drawing_surface"
const DRAW_TOOL_ID := "charcoal"
const CONTEXT_IDS: Array[String] = ["hungry", "curious", "fatigued", "social", "settled"]
const INPUT_NAMES: Array[String] = [
	"glucose", "hunger", "curiosity", "fatigue", "reward",
	"punishment", "stress", "socialComfort", "arousal", "satiety",
	"nearFruit", "nearSpinner", "peerNearby", "guidance",
	"fruitAffordance", "spinnerAffordance", "fruitLanguageSignal", "spinnerLanguageSignal",
	"praiseSignal", "scoldSignal"
]
const REACTION_TABLE := [
	{"id": "metabolism", "target": "hunger", "rate": 1.55},
	{"id": "curiosity", "target": "curiosity", "rate": 0.68, "trait": "curiosity", "traitRate": 0.34},
	{"id": "glucose-use", "target": "glucose", "rate": -0.55},
	{"id": "active-fatigue", "target": "fatigue", "rate": 0.12, "stimulus": "active"},
	{"id": "rest-recovery", "target": "fatigue", "rate": -0.36, "stimulus": "resting"},
	{"id": "reward-decay", "target": "reward", "rate": -7.0},
	{"id": "punishment-decay", "target": "punishment", "rate": -7.0},
	{"id": "stress-decay", "target": "stress", "rate": -1.6},
	{"id": "social-comfort-decay", "target": "socialComfort", "rate": -0.15},
	{"id": "peer-comfort", "target": "socialComfort", "rate": 0.55, "stimulus": "nearbyPeer"},
	{"id": "arousal-decay", "target": "arousal", "rate": -0.6},
	{"id": "satiety-decay", "target": "satiety", "rate": -0.8}
]
const CHEMICAL_COUPLINGS := [
	{"source": "stress", "target": "arousal", "rate": 0.12},
	{"source": "reward", "target": "stress", "rate": -0.08},
	{"source": "punishment", "target": "stress", "rate": 0.1},
	{"source": "satiety", "target": "hunger", "rate": -0.03},
	{"source": "hunger", "target": "stress", "rate": 0.025}
]


static func create_state(seed: int, traits: Dictionary = {}, initial: Dictionary = {}) -> Dictionary:
	var stable_seed := seed & 0xffffffff
	if stable_seed == 0:
		stable_seed = 1
	var hunger := clampf(_finite_or(initial.get("hunger", 45.0), 45.0), 0.0, 100.0)
	var curiosity := clampf(_finite_or(initial.get("curiosity", 45.0), 45.0), 0.0, 100.0)
	var chemistry := {
		"glucose": 100.0 - hunger,
		"hunger": hunger,
		"curiosity": curiosity,
		"fatigue": clampf(_finite_or(initial.get("fatigue", 15.0), 15.0), 0.0, 100.0),
		"reward": 0.0,
		"punishment": 0.0,
		"stress": 0.0,
		"socialComfort": 50.0,
		"arousal": curiosity * 0.35,
		"satiety": clampf(100.0 - hunger, 0.0, 100.0)
	}
	var safe_traits := {
		"curiosity": clampf(_finite_or(traits.get("curiosity", 0.5), 0.5), 0.0, 1.0),
		"sociability": clampf(_finite_or(traits.get("sociability", 0.5), 0.5), 0.0, 1.0)
	}
	var associations: Dictionary = initial.get("actionAssociations", initial.get("learned", {}))
	var policy := _make_policy(stable_seed)
	var hidden := PackedFloat32Array()
	hidden.resize(RECURRENT_UNITS)
	return {
		"version": VERSION,
		"seed": stable_seed,
		"traits": safe_traits,
		"chemistry": chemistry,
		"actionAssociations": _normalize_associations(associations),
		"contextAssociations": _normalize_context_map(initial.get("contextAssociations", {})),
		"episodes": [],
		"nextEpisodeId": 1,
		"eligibility": _make_action_map(0.0),
		"contextEligibility": _make_context_map(0.0),
		"hidden": hidden,
		"decisionCount": 0,
		"commitmentUntil": 0.0,
		"lastDecision": null,
		"policy": policy
	}


static func advance_chemistry(state: Dictionary, stimuli: Dictionary = {}, dt: float = 0.1) -> Dictionary:
	if not state.has("chemistry") or not _is_finite_number(dt) or dt <= 0.0:
		return {}
	var seconds := clampf(dt, 0.0, 0.5)
	var bounded_stimuli := {
		"active": clampf(_finite_or(stimuli.get("active", 0.0), 0.0), 0.0, 1.0),
		"resting": clampf(_finite_or(stimuli.get("resting", 0.0), 0.0), 0.0, 1.0),
		"nearbyPeer": clampf(_finite_or(stimuli.get("nearbyPeer", 0.0), 0.0), 0.0, 1.0),
		"stress": clampf(_finite_or(stimuli.get("stress", 0.0), 0.0), -1.0, 1.0)
	}
	var chemistry: Dictionary = state["chemistry"]
	var deltas := _make_actionless_chemical_map()
	var traits: Dictionary = state["traits"]
	for reaction: Dictionary in REACTION_TABLE:
		var rate := float(reaction["rate"])
		if reaction.has("trait"):
			rate += float(traits.get(reaction["trait"], 0.5)) * float(reaction["traitRate"])
		if reaction.has("stimulus"):
			rate *= float(bounded_stimuli[reaction["stimulus"]])
		deltas[reaction["target"]] = float(deltas[reaction["target"]]) + rate * seconds
	deltas["stress"] = float(deltas["stress"]) + float(bounded_stimuli["stress"]) * seconds
	for coupling: Dictionary in CHEMICAL_COUPLINGS:
		var delta := float(chemistry[coupling["source"]]) / 100.0 * float(coupling["rate"]) * seconds
		deltas[coupling["target"]] = float(deltas[coupling["target"]]) + delta
	for chemical: String in CHEMICAL_NAMES:
		chemistry[chemical] = clampf(float(chemistry[chemical]) + float(deltas[chemical]), 0.0, 100.0)
	return chemistry.duplicate(true)


static func sync_chemistry(state: Dictionary, signals: Dictionary) -> bool:
	if not state.has("chemistry") or not _valid_chemistry_signals(signals):
		return false
	state["chemistry"] = signals.duplicate(true)
	return true


static func decide(state: Dictionary, observation: Dictionary = {}) -> Dictionary:
	if not state.has("policy"):
		return {}
	_update_recurrent_state(state, observation)
	var decision := _apply_commitment(state, _score_decision(state, observation), observation, true)
	if decision.get("actionId", "") == "draw":
		decision["drawMotorCommand"] = draw_motor_command(state)
	var saved_decision := decision.duplicate(true)
	for diagnostic: String in ["eligibleActions", "scoreBreakdown", "safetyOverride", "drawMotorCommand"]:
		saved_decision.erase(diagnostic)
	state["lastDecision"] = saved_decision
	return decision.duplicate(true)


static func preview(state: Dictionary, observation: Dictionary = {}) -> Dictionary:
	if not state.has("policy"):
		return {}
	var decision := _apply_commitment(state, _score_decision(state, observation), observation, false)
	if decision.get("actionId", "") == "draw":
		decision["drawMotorCommand"] = draw_motor_command(state)
	return decision.duplicate(true)


static func draw_motor_command(state: Dictionary) -> Dictionary:
	if not state.has("policy") or not (state["policy"] is Dictionary):
		return {}
	var policy: Dictionary = state["policy"]
	var weights: PackedFloat32Array = policy.get("motorWeights", PackedFloat32Array())
	var biases: PackedFloat32Array = policy.get("motorBiases", PackedFloat32Array())
	var hidden: PackedFloat32Array = state.get("hidden", PackedFloat32Array())
	if weights.size() != MOTOR_OUTPUT_COUNT * RECURRENT_UNITS or biases.size() != MOTOR_OUTPUT_COUNT or hidden.size() != RECURRENT_UNITS:
		return {}
	var outputs := PackedFloat32Array()
	outputs.resize(MOTOR_OUTPUT_COUNT)
	for output_index: int in range(MOTOR_OUTPUT_COUNT):
		var activation := float(biases[output_index])
		var offset := output_index * RECURRENT_UNITS
		for unit: int in range(RECURRENT_UNITS):
			activation += float(weights[offset + unit]) * float(hidden[unit])
		outputs[output_index] = tanh(activation)
	var seed_phase := posmod(int(state.get("seed", 0)), 8)
	var decision_phase := posmod(int(state.get("decisionCount", 0)) + seed_phase, 8)
	return {
		"dx": outputs[0] * 0.08,
		"dy": outputs[1] * 0.08,
		"pressure": clampf(0.45 + outputs[2] * 0.4, 0.05, 0.85),
		"contact": decision_phase != 7
	}


static func select_observation_peer(state: Dictionary, candidates: Array[Dictionary], parent_ids: Array[String], life_stage: String, now: float) -> Dictionary:
	var scores: Array[Dictionary] = []
	var seen_peer_ids: Dictionary = {}
	for candidate: Dictionary in candidates:
		var peer_id_value: Variant = candidate.get("id", null)
		if not (peer_id_value is String):
			continue
		var peer_id := str(peer_id_value)
		if peer_id.is_empty() or seen_peer_ids.has(peer_id):
			continue
		var distance_value: Variant = candidate.get("distance", null)
		if not _is_finite_number(distance_value):
			continue
		var distance := float(distance_value)
		if distance < 0.0:
			continue
		seen_peer_ids[peer_id] = true
		var proximity := clampf(1.0 - distance / PEER_SELECTION_RADIUS, 0.0, 1.0)
		var age_bonus := ADOLESCENT_NON_PARENT_BONUS if life_stage == "adolescent" and not parent_ids.has(peer_id) else 0.0
		var memory_score := _peer_social_memory_score(state, peer_id, now)
		scores.append({
			"peerId": peer_id,
			"distance": distance,
			"proximity": proximity,
			"ageBonus": age_bonus,
			"memory": memory_score,
			"total": proximity + age_bonus + memory_score
		})
	if scores.is_empty():
		return {}
	scores.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_score := float(left["total"])
		var right_score := float(right["total"])
		if left_score != right_score:
			return left_score > right_score
		var left_distance := float(left["distance"])
		var right_distance := float(right["distance"])
		if left_distance != right_distance:
			return left_distance < right_distance
		return str(left["peerId"]) < str(right["peerId"])
	)
	var selected: Dictionary = scores[0]
	var reason_key := "proximity"
	var reason_peer_id := ""
	var most_negative_memory := 0.0
	for score: Dictionary in scores:
		var peer_memory := float(score["memory"])
		if peer_memory < most_negative_memory:
			most_negative_memory = peer_memory
			reason_peer_id = str(score["peerId"])
	if float(selected["memory"]) >= 0.1:
		reason_key = "positive_memory"
		reason_peer_id = str(selected["peerId"])
	elif most_negative_memory <= -0.1 and str(selected["peerId"]) != reason_peer_id:
		reason_key = "negative_memory"
	elif float(selected["ageBonus"]) > 0.0:
		reason_key = "adolescent_preference"
	return {
		"peerId": str(selected["peerId"]),
		"reasonKey": reason_key,
		"reasonPeerId": reason_peer_id,
		"scores": scores.duplicate(true)
	}


static func record_outcome(state: Dictionary, outcome: Dictionary = {}, external_chemistry: Dictionary = {}) -> Dictionary:
	if not state.has("chemistry"):
		return {}
	var event_type := str(outcome.get("eventType", "experience"))
	var action_id := str(outcome.get("actionId", ""))
	if not ACTION_IDS.has(action_id):
		action_id = ""
	var target_id = outcome.get("targetId", null)
	if not (target_id is String):
		target_id = null
	var chemistry: Dictionary = state["chemistry"]
	var before: Dictionary = chemistry.duplicate(true)
	if not external_chemistry.is_empty():
		var external_before = external_chemistry.get("before", null)
		var external_after = external_chemistry.get("after", null)
		if not _valid_chemistry_signals(external_before) or not _valid_chemistry_signals(external_after):
			return {}
		before = external_before.duplicate(true)
		chemistry = external_after.duplicate(true)
		state["chemistry"] = chemistry
	var peer_count := maxi(0, int(_finite_or(outcome.get("peerCount", 0), 0.0)))
	var contexts := _get_context_ids(before, peer_count)
	if external_chemistry.is_empty():
		_adjust_chemistry_for_outcome(chemistry, event_type, str(outcome.get("feedback", "")))
	var explicit_delta = outcome.get("learningDelta", null)
	var learning_delta := _derive_learning_delta(event_type, explicit_delta)
	var learning_multiplier := clampf(_finite_or(outcome.get("learningMultiplier", 1.0), 1.0), 0.0, 2.0)
	if event_type == "observe" and _is_finite_number(outcome.get("sociability", null)):
		learning_delta = (0.06 + clampf(float(outcome["sociability"]), 0.0, 1.0) * 0.04) * learning_multiplier
	elif event_type == "observe-feedback" and _is_finite_number(outcome.get("sociability", null)):
		var direction := -1.0 if outcome.get("feedback", "") == "scold" else 1.0
		learning_delta = direction * (0.04 + clampf(float(outcome["sociability"]), 0.0, 1.0) * 0.03) * learning_multiplier

	var eligibility: Dictionary = state["eligibility"]
	var context_eligibility: Dictionary = state["contextEligibility"]
	for id: String in ACTION_IDS:
		eligibility[id] = clampf(float(eligibility[id]) * 0.88, 0.0, 1.0)
		for context_id: String in CONTEXT_IDS:
			context_eligibility[id][context_id] = clampf(float(context_eligibility[id][context_id]) * 0.88, 0.0, 1.0)
	if not action_id.is_empty():
		eligibility[action_id] = 1.0
		for context_id: String in contexts:
			context_eligibility[action_id][context_id] = 1.0
	var valence := 0.0
	if event_type == "scold" or (event_type == "observe-feedback" and outcome.get("feedback", "") == "scold"):
		valence = -1.0
	elif ["food", "toy", "praise", "observe", "observe-feedback"].has(event_type):
		valence = 1.0
	var associations: Dictionary = state["actionAssociations"]
	var context_associations: Dictionary = state["contextAssociations"]
	if not action_id.is_empty() and learning_delta != 0.0:
		associations[action_id] = clampf(float(associations[action_id]) + learning_delta, 0.0, 1.0)
		for context_id: String in contexts:
			context_associations[action_id][context_id] = clampf(
				float(context_associations[action_id][context_id]) + learning_delta * 0.5,
				0.0,
				1.0
			)
	var reward_signal := clampf(_finite_or(outcome.get("reward", valence), valence), -1.0, 1.0)
	if reward_signal != 0.0:
		var remaining_change := maxf(0.0, 0.2 - absf(learning_delta))
		var trace_order := _trace_order(action_id)
		for id: String in trace_order:
			var trace := float(eligibility[id])
			var change := clampf(reward_signal * trace * 0.04, -remaining_change, remaining_change)
			if change != 0.0:
				associations[id] = clampf(float(associations[id]) + change, 0.0, 1.0)
				remaining_change = maxf(0.0, remaining_change - absf(change))
		var remaining_context_change := maxf(0.0, 0.1 - absf(learning_delta * 0.5))
		for id: String in trace_order:
			for context_id: String in contexts:
				var trace := float(context_eligibility[id][context_id])
				var change := clampf(reward_signal * trace * 0.02, -remaining_context_change, remaining_context_change)
				if change != 0.0:
					context_associations[id][context_id] = clampf(
						float(context_associations[id][context_id]) + change,
						0.0,
						1.0
					)
					remaining_context_change = maxf(0.0, remaining_context_change - absf(change))

	var episode_id := int(state["nextEpisodeId"])
	state["nextEpisodeId"] = episode_id + 1
	var salience_default := 0.9 if ["food", "toy"].has(event_type) else 0.55
	var episode := {
		"id": episode_id,
		"time": maxf(0.0, _finite_or(outcome.get("time", 0.0), 0.0)),
		"observation": {
			"hunger": before["hunger"],
			"curiosity": before["curiosity"],
			"fatigue": before["fatigue"],
			"peerCount": peer_count
		},
		"actorId": str(outcome.get("actorId", "")).left(32) if outcome.get("actorId", null) is String else null,
		"actionId": action_id if not action_id.is_empty() else null,
		"targetId": target_id,
		"chemicalsBefore": before,
		"chemicalsAfter": chemistry.duplicate(true),
		"outcome": event_type,
		"eventType": event_type,
		"feedback": str(outcome.get("feedback", "")).left(16),
		"sociability": clampf(float(outcome["sociability"]), 0.0, 1.0) if _is_finite_number(outcome.get("sociability", null)) else null,
		"linkedEventId": int(outcome.get("eventId", 0)) if int(outcome.get("eventId", 0)) > 0 else null,
		"salience": clampf(_finite_or(outcome.get("salience", salience_default), salience_default), 0.0, 1.0),
		"valence": int(valence),
		"text": str(outcome.get("text", "")).left(500),
		"word": str(outcome.get("word", "")).left(24) if outcome.get("word", null) is String else null,
		"surfaceId": str(outcome.get("surfaceId", "")).left(32) if outcome.get("surfaceId", null) is String else null,
		"toolId": str(outcome.get("toolId", "")).left(32) if outcome.get("toolId", null) is String else null,
		"strokeData": outcome.get("strokeData", null).duplicate(true) if outcome.get("strokeData", null) is Dictionary else null
	}
	var episodes: Array = state["episodes"]
	episodes.append(episode)
	if episodes.size() > EPISODE_LIMIT:
		episodes = episodes.slice(episodes.size() - EPISODE_LIMIT)
		state["episodes"] = episodes
	return {
		"episodeId": episode_id,
		"actionId": action_id if not action_id.is_empty() else null,
		"association": float(associations[action_id]) if not action_id.is_empty() else null,
		"learningDelta": learning_delta
	}


static func serialize_state(state: Dictionary) -> Dictionary:
	if not state.has("chemistry"):
		return {}
	var hidden_values: Array[float] = []
	var hidden: PackedFloat32Array = state["hidden"]
	for value: float in hidden:
		hidden_values.append(value)
	return {
		"version": VERSION,
		"seed": state["seed"],
		"traits": (state["traits"] as Dictionary).duplicate(true),
		"chemistry": (state["chemistry"] as Dictionary).duplicate(true),
		"actionAssociations": (state["actionAssociations"] as Dictionary).duplicate(true),
		"contextAssociations": (state["contextAssociations"] as Dictionary).duplicate(true),
		"episodes": (state["episodes"] as Array).duplicate(true),
		"nextEpisodeId": state["nextEpisodeId"],
		"eligibility": (state["eligibility"] as Dictionary).duplicate(true),
		"contextEligibility": (state["contextEligibility"] as Dictionary).duplicate(true),
		"recurrent": {"hidden": hidden_values, "decisionCount": state["decisionCount"]},
		"commitmentUntil": state["commitmentUntil"],
	"lastDecision": (state["lastDecision"] as Dictionary).duplicate(true) if state["lastDecision"] is Dictionary else null
	}


static func restore_state(record: Dictionary) -> Dictionary:
	if not _valid_record(record):
		return {}
	var record_version := int(record.get("version", VERSION))
	var traits: Dictionary = record["traits"]
	var chemistry: Dictionary = record["chemistry"]
	var associations: Dictionary = record["actionAssociations"]
	if record_version == 1:
		associations = _migrate_legacy_action_associations(associations)
	var state := create_state(int(record["seed"]), traits, {
		"hunger": chemistry["hunger"],
		"curiosity": chemistry["curiosity"],
		"fatigue": chemistry["fatigue"],
		"actionAssociations": associations
	})
	state["chemistry"] = chemistry.duplicate(true)
	state["contextAssociations"] = _normalize_context_map(record["contextAssociations"])
	state["episodes"] = (record["episodes"] as Array).duplicate(true)
	state["nextEpisodeId"] = record["nextEpisodeId"]
	state["eligibility"] = _normalize_associations(record["eligibility"], 0.0)
	state["contextEligibility"] = _normalize_context_map(record["contextEligibility"], 0.0)
	state["hidden"] = PackedFloat32Array(record["recurrent"]["hidden"])
	state["decisionCount"] = record["recurrent"]["decisionCount"]
	state["commitmentUntil"] = record["commitmentUntil"]
	state["lastDecision"] = _migrate_last_decision(record["lastDecision"], record_version)
	return state


static func _migrate_last_decision(value: Variant, record_version: int) -> Variant:
	if not (value is Dictionary):
		return null
	var decision: Dictionary = value.duplicate(true)
	if record_version < VERSION:
		var scores: Dictionary = decision.get("actionScores", {}).duplicate(true)
		scores["draw"] = 0.0
		decision["actionScores"] = scores
		var components: Dictionary = decision.get("components", {}).duplicate(true)
		components["drawNeed"] = 0.0
		decision["components"] = components
	return decision


static func get_chemical_names() -> Array[String]:
	return CHEMICAL_NAMES.duplicate()


static func get_action_ids() -> Array[String]:
	return ACTION_IDS.duplicate()


static func _valid_chemistry_signals(signals: Variant) -> bool:
	if not (signals is Dictionary) or signals.size() != CHEMICAL_NAMES.size():
		return false
	for chemical: String in CHEMICAL_NAMES:
		var value = signals.get(chemical, null)
		if not _is_finite_number(value) or float(value) < 0.0 or float(value) > 100.0:
			return false
	return true


static func _make_policy(seed: int) -> Dictionary:
	var rng := {"state": (seed ^ 0x9e3779b9) & 0xffffffff}
	var input_weights := PackedFloat32Array()
	input_weights.resize(RECURRENT_UNITS * INPUT_COUNT)
	input_weights.fill(0.0)
	var recurrent_indices := PackedInt32Array()
	recurrent_indices.resize(RECURRENT_UNITS * RECURRENT_DEGREE)
	var recurrent_weights := PackedFloat32Array()
	recurrent_weights.resize(RECURRENT_UNITS * RECURRENT_DEGREE)
	var action_weights := PackedFloat32Array()
	action_weights.resize(ACTION_IDS.size() * RECURRENT_UNITS)
	for unit: int in range(RECURRENT_UNITS):
		var input_offset := unit * INPUT_COUNT
		for index: int in range(NAMED_INPUT_COUNT):
			input_weights[input_offset + index] = (_next_random(rng) * 2.0 - 1.0) * 0.12
	for unit: int in range(RECURRENT_UNITS):
		for edge: int in range(RECURRENT_DEGREE):
			var offset := unit * RECURRENT_DEGREE + edge
			recurrent_indices[offset] = int(floor(_next_random(rng) * RECURRENT_UNITS))
			recurrent_weights[offset] = (_next_random(rng) * 2.0 - 1.0) * 0.16
	for index: int in range(action_weights.size()):
		action_weights[index] = (_next_random(rng) * 2.0 - 1.0) * 0.055
	var visual_rng := {"state": ((seed ^ 0x85ebca6b) & 0xffffffff)}
	if int(visual_rng["state"]) == 0:
		visual_rng["state"] = 1
	for unit: int in range(RECURRENT_UNITS):
		var visual_offset := unit * INPUT_COUNT + NAMED_INPUT_COUNT
		for mark_index: int in range(MARK_INPUT_COUNT):
			input_weights[visual_offset + mark_index] = (_next_random(visual_rng) * 2.0 - 1.0) * 0.12
	var motor_rng := {"state": ((seed ^ 0x27d4eb2d) & 0xffffffff)}
	if int(motor_rng["state"]) == 0:
		motor_rng["state"] = 1
	var motor_weights := PackedFloat32Array()
	motor_weights.resize(MOTOR_OUTPUT_COUNT * RECURRENT_UNITS)
	for index: int in range(motor_weights.size()):
		motor_weights[index] = (_next_random(motor_rng) * 2.0 - 1.0) * 0.08
	var motor_biases := PackedFloat32Array()
	motor_biases.resize(MOTOR_OUTPUT_COUNT)
	for index: int in range(motor_biases.size()):
		motor_biases[index] = (_next_random(motor_rng) * 2.0 - 1.0) * 0.15
	return {
		"inputWeights": input_weights,
		"recurrentIndices": recurrent_indices,
		"recurrentWeights": recurrent_weights,
		"actionWeights": action_weights,
		"motorWeights": motor_weights,
		"motorBiases": motor_biases
	}


static func _next_random(rng: Dictionary) -> float:
	var value: int = int(rng["state"])
	value = (value * 1664525 + 1013904223) & 0xffffffff
	rng["state"] = value
	return float(value) / 4294967296.0


static func _normalize_associations(source: Dictionary, default_value: float = 0.5) -> Dictionary:
	var result := {}
	for action_id: String in ACTION_IDS:
		result[action_id] = clampf(_finite_or(source.get(action_id, default_value), default_value), 0.0, 1.0)
	return result


static func _migrate_legacy_action_associations(source: Dictionary) -> Dictionary:
	var result := {}
	for action_id: String in ACTION_IDS:
		var legacy_value := clampf(_finite_or(source.get(action_id, 0.0), 0.0), 0.0, 1.0)
		result[action_id] = 0.5 + legacy_value * 0.5
	return result


static func _make_action_map(value: float) -> Dictionary:
	var result := {}
	for action_id: String in ACTION_IDS:
		result[action_id] = value
	return result


static func _make_context_map(value: float = 0.5) -> Dictionary:
	var result := {}
	for action_id: String in ACTION_IDS:
		var contexts := {}
		for context_id: String in CONTEXT_IDS:
			contexts[context_id] = value
		result[action_id] = contexts
	return result


static func _normalize_context_map(source: Dictionary, fallback: float = 0.5) -> Dictionary:
	var result := _make_context_map(fallback)
	for action_id: String in ACTION_IDS:
		var row: Dictionary = result[action_id]
		var source_row = source.get(action_id, {})
		if not (source_row is Dictionary):
			continue
		for context_id: String in CONTEXT_IDS:
			row[context_id] = clampf(_finite_or(source_row.get(context_id, fallback), fallback), 0.0, 1.0)
	return result


static func _get_context_ids(chemistry: Dictionary, peer_count: int) -> Array[String]:
	var contexts: Array[String] = []
	if float(chemistry["hunger"]) >= 35.0:
		contexts.append("hungry")
	if float(chemistry["curiosity"]) >= 40.0:
		contexts.append("curious")
	if float(chemistry["fatigue"]) >= 40.0:
		contexts.append("fatigued")
	if peer_count > 0:
		contexts.append("social")
	if contexts.is_empty():
		contexts.append("settled")
	return contexts


static func _update_recurrent_state(state: Dictionary, observation: Dictionary) -> void:
	var policy: Dictionary = state["policy"]
	var input_weights: PackedFloat32Array = policy["inputWeights"]
	var recurrent_indices: PackedInt32Array = policy["recurrentIndices"]
	var recurrent_weights: PackedFloat32Array = policy["recurrentWeights"]
	var input := _get_input_vector(state, observation)
	var previous: PackedFloat32Array = state["hidden"]
	var next_hidden := PackedFloat32Array()
	next_hidden.resize(RECURRENT_UNITS)
	for unit: int in range(RECURRENT_UNITS):
		var activation := 0.0
		var input_offset := unit * INPUT_COUNT
		for index: int in range(INPUT_COUNT):
			activation += input_weights[input_offset + index] * input[index]
		var edge_offset := unit * RECURRENT_DEGREE
		for edge: int in range(RECURRENT_DEGREE):
			var weight_index := edge_offset + edge
			activation += recurrent_weights[weight_index] * previous[recurrent_indices[weight_index]]
		next_hidden[unit] = tanh(activation * 1.4)
	state["hidden"] = next_hidden
	state["decisionCount"] = int(state["decisionCount"]) + 1


static func _get_input_vector(state: Dictionary, observation: Dictionary) -> Array[float]:
	var chemistry: Dictionary = observation.get("chemistry", state["chemistry"])
	var input: Array[float] = []
	for chemical: String in CHEMICAL_NAMES:
		input.append(_normalized(float(chemistry.get(chemical, 0.0))))
	var objects_value: Variant = observation.get("nearbyObjects", [])
	var objects: Array = objects_value if objects_value is Array else []
	var fruit: Dictionary = _find_object(objects, "fruit")
	var spinner: Dictionary = _find_object(objects, "spinner")
	var peers: Array = observation.get("nearbyNorns", [])
	var guidance = observation.get("guidance", null)
	var languages: Dictionary = observation.get("languageSignals", {})
	var guidance_active := guidance is Dictionary and ["fruit", "spinner"].has(guidance.get("objectId", ""))
	input.append(_distance_signal(fruit))
	input.append(_distance_signal(spinner))
	input.append(1.0 if not peers.is_empty() else 0.0)
	input.append(1.0 if guidance_active else 0.0)
	input.append(1.0 if fruit.has("affordances") and (fruit["affordances"] as Array).has("eat") else 0.0)
	input.append(1.0 if spinner.has("affordances") and (spinner["affordances"] as Array).has("play") else 0.0)
	input.append(1.0 if languages.get("targetId", "") == "fruit" else 0.0)
	input.append(1.0 if languages.get("targetId", "") == "spinner" else 0.0)
	input.append(1.0 if bool(languages.get("praise", false)) else 0.0)
	input.append(1.0 if bool(languages.get("scold", false)) else 0.0)
	var surface_visible := _has_sensed_id(objects, DRAW_SURFACE_ID)
	var mark_values: Variant = observation.get("surfaceMarks", null)
	for mark_index: int in range(MARK_INPUT_COUNT):
		var mark_value := 0.0
		if surface_visible and mark_values is PackedFloat32Array and mark_values.size() == MARK_INPUT_COUNT:
			mark_value = clampf(_finite_or(mark_values[mark_index], 0.0), 0.0, 1.0)
		elif surface_visible and mark_values is Array and mark_values.size() == MARK_INPUT_COUNT:
			mark_value = clampf(_finite_or(mark_values[mark_index], 0.0), 0.0, 1.0)
		input.append(mark_value)
	return input


static func _find_object(objects: Array, object_id: String) -> Dictionary:
	for item in objects:
		if item is Dictionary and item.get("id", "") == object_id:
			return item
	return {}


static func _distance_signal(item: Dictionary) -> float:
	if item.is_empty():
		return 0.0
	return clampf(1.0 - maxf(0.0, _finite_or(item.get("distance", 0.0), 0.0)) / 900.0, 0.0, 1.0)


static func _policy_signals(state: Dictionary) -> Dictionary:
	var result := {}
	var policy: Dictionary = state["policy"]
	var action_weights: PackedFloat32Array = policy["actionWeights"]
	var hidden: PackedFloat32Array = state["hidden"]
	for action_index: int in range(ACTION_IDS.size()):
		var value := 0.0
		var offset := action_index * RECURRENT_UNITS
		for unit: int in range(RECURRENT_UNITS):
			value += action_weights[offset + unit] * hidden[unit]
		result[ACTION_IDS[action_index]] = clampf(value * 3.0, -2.5, 2.5)
	return result


static func _retrieve_episodes(state: Dictionary, observation: Dictionary, limit: int = 3) -> Array[Dictionary]:
	var now := maxf(0.0, _finite_or(observation.get("time", 0.0), 0.0))
	var chemistry: Dictionary = observation.get("chemistry", state["chemistry"])
	var target_id = observation.get("targetId", null)
	var guidance = observation.get("guidance", null)
	if target_id == null and guidance is Dictionary:
		target_id = guidance.get("objectId", null)
	var nearby_norns: Array = observation.get("nearbyNorns", [])
	var peers_nearby := not nearby_norns.is_empty()
	var scored: Array[Dictionary] = []
	for episode: Dictionary in state["episodes"]:
		var age := maxf(0.0, now - float(episode.get("time", 0.0)))
		var recency := 1.0 / (1.0 + age / 45.0)
		var target_match := 1.0 if target_id != null and episode.get("targetId", null) == target_id else 0.0
		var peer_match := 1.0 if peers_nearby and ["observe", "observe-feedback", "hear"].has(episode.get("eventType", "")) else 0.0
		var episode_observation: Dictionary = episode.get("observation", {})
		var drive_match := 1.0 - (
			absf(float(episode_observation.get("hunger", 0.0)) - float(chemistry["hunger"]))
			+ absf(float(episode_observation.get("curiosity", 0.0)) - float(chemistry["curiosity"]))
		) / 200.0
		var context := maxf(target_match, maxf(peer_match, drive_match * 0.5))
		var score := float(episode.get("salience", 0.0)) * 0.52 + recency * 0.28 + context * 0.2
		scored.append({"episode": episode, "score": score})
	var result: Array[Dictionary] = []
	var wanted := clampi(limit, 0, 3)
	while result.size() < wanted and not scored.is_empty():
		var best_index := 0
		for index: int in range(1, scored.size()):
			var candidate: Dictionary = scored[index]
			var best: Dictionary = scored[best_index]
			if float(candidate["score"]) > float(best["score"]) or (
				is_equal_approx(float(candidate["score"]), float(best["score"]))
				and int(candidate["episode"]["id"]) > int(best["episode"]["id"])
			):
				best_index = index
		result.append(scored[best_index]["episode"])
		scored.remove_at(best_index)
	return result


static func _episodic_action_bias(episodes: Array[Dictionary], action_id: String) -> float:
	var bias := 0.0
	for episode: Dictionary in episodes:
		if episode.get("actionId", null) != action_id or int(episode.get("valence", 0)) == 0:
			continue
		bias += float(episode["valence"]) * float(episode["salience"]) * 2.4
	return clampf(bias, -4.0, 4.0)


static func _contextual_action_bias(state: Dictionary, action_id: String, contexts: Array[String]) -> float:
	var associations: Dictionary = state["contextAssociations"]
	var total := 0.0
	for context_id: String in contexts:
		total += (float(associations[action_id][context_id]) - 0.5) * 12.0
	return total / float(contexts.size()) if not contexts.is_empty() else 0.0


static func _score_decision(state: Dictionary, observation: Dictionary) -> Dictionary:
	var chemistry: Dictionary = observation.get("chemistry", state["chemistry"])
	var associations: Dictionary = state["actionAssociations"]
	var policy: Dictionary = _policy_signals(state)
	var recalled: Array[Dictionary] = _retrieve_episodes(state, observation)
	var hunger := clampf(float(chemistry["hunger"]), 0.0, 100.0)
	var glucose := clampf(float(chemistry["glucose"]), 0.0, 100.0)
	var curiosity := clampf(float(chemistry["curiosity"]), 0.0, 100.0)
	var fruit_need := maxf(hunger, 100.0 - glucose)
	var spinner_need := maxf(0.0, curiosity - 16.0) * (0.58 + float(state["traits"]["curiosity"]) * 0.46)
	var draw_need := maxf(0.0, curiosity - 20.0) * 0.34 * (0.7 + float(state["traits"]["curiosity"]) * 0.3)
	var nearby_norns: Array = observation.get("nearbyNorns", [])
	var contexts := _get_context_ids(chemistry, nearby_norns.size())
	var low_glucose_need := 100.0 - glucose
	var rest_need := clampf(float(chemistry["fatigue"]) * 0.85 + low_glucose_need * 0.15, 0.0, 100.0)
	var sociability := clampf(float(state["traits"].get("sociability", 0.5)), 0.0, 1.0)
	var observe_need := 8.0 + maxf(0.0, 50.0 - float(chemistry["socialComfort"])) * 0.12 + sociability * 20.0 if not nearby_norns.is_empty() else 0.0
	var drives := {
		"fruit": fruit_need,
		"spinner": clampf(spinner_need, 0.0, 100.0),
		"rest": rest_need,
		"observe_peer": observe_need,
		"idle": 24.0,
		"draw": clampf(draw_need, 0.0, 40.0)
	}
	var action_scores: Dictionary = {}
	var score_breakdown: Dictionary = {}
	for action_id: String in ACTION_IDS:
		var action_association := _action_association_bias(associations, action_id)
		var context_association := _contextual_action_bias(state, action_id, contexts)
		var episodic_memory := _episodic_action_bias(recalled, action_id)
		var recurrent_policy := float(policy[action_id])
		var combined_preference := clampf(
			action_association + context_association + episodic_memory + recurrent_policy,
			-ACTION_NON_DRIVE_LIMIT,
			ACTION_NON_DRIVE_LIMIT
		)
		var final_utility := clampf(float(drives[action_id]) + combined_preference, ACTION_UTILITY_MIN, ACTION_UTILITY_MAX)
		action_scores[action_id] = final_utility
		score_breakdown[action_id] = {
			"drive": float(drives[action_id]),
			"actionAssociation": action_association,
			"contextAssociation": context_association,
			"episodicMemory": episodic_memory,
			"recurrentPolicy": recurrent_policy,
			"combinedPreference": combined_preference,
			"finalUtility": final_utility
		}
	var eligible_actions := _eligible_actions(observation)
	var action_id := _highest_utility_action(action_scores, eligible_actions)
	var safety_override := ""
	var fruit_urgent := eligible_actions.has("fruit") and (hunger >= FRUIT_URGENT_HUNGER or glucose <= FRUIT_URGENT_GLUCOSE)
	var rest_urgent := eligible_actions.has("rest") and float(chemistry["fatigue"]) >= REST_URGENT_FATIGUE
	if fruit_urgent and rest_urgent:
		var fruit_severity := maxf(
			clampf((hunger - FRUIT_URGENT_HUNGER) / (100.0 - FRUIT_URGENT_HUNGER), 0.0, 1.0),
			clampf((FRUIT_URGENT_GLUCOSE - glucose) / FRUIT_URGENT_GLUCOSE, 0.0, 1.0)
		)
		var rest_severity := clampf((float(chemistry["fatigue"]) - REST_URGENT_FATIGUE) / (100.0 - REST_URGENT_FATIGUE), 0.0, 1.0)
		if fruit_severity >= rest_severity:
			action_id = "fruit"
			safety_override = "fruit"
		else:
			action_id = "rest"
			safety_override = "rest"
	elif fruit_urgent:
		action_id = "fruit"
		safety_override = "fruit"
	elif rest_urgent:
		action_id = "rest"
		safety_override = "rest"
	var reason := _decision_reason(action_id, score_breakdown[action_id], hunger, glucose)
	if safety_override == "fruit":
		reason = "Urgent hunger or low glucose is calling for food"
	elif safety_override == "rest":
		reason = "Extreme fatigue is calling for rest"
	var fruit_habit := float(associations["fruit"]) * 35.0
	var spinner_habit := float(associations["spinner"]) * 32.0
	var fruit_context := clampf(float(policy["fruit"]) + _episodic_action_bias(recalled, "fruit") + _contextual_action_bias(state, "fruit", contexts), -8.0, 8.0)
	var spinner_context := clampf(float(policy["spinner"]) + _episodic_action_bias(recalled, "spinner") + _contextual_action_bias(state, "spinner", contexts), -8.0, 8.0)
	return {
		"actionId": action_id,
		"actionScores": action_scores,
		"reason": reason,
		"recalledEpisodeIds": recalled.map(func(episode: Dictionary) -> int: return int(episode["id"])),
		"eligibleActions": eligible_actions,
		"scoreBreakdown": score_breakdown,
		"safetyOverride": safety_override,
		"components": {
			"fruitNeed": fruit_need, "fruitHabit": fruit_habit, "fruitContext": fruit_context, "fruitScore": float(action_scores["fruit"]),
			"spinnerNeed": spinner_need, "spinnerHabit": spinner_habit, "spinnerContext": spinner_context, "spinnerScore": float(action_scores["spinner"]),
			"restNeed": rest_need, "observeNeed": observe_need, "drawNeed": draw_need
		}
	}


static func _action_association_bias(associations: Dictionary, action_id: String) -> float:
	var weight := 20.0
	if action_id == "fruit":
		weight = 35.0
	elif action_id == "spinner":
		weight = 32.0
	return (float(associations[action_id]) - 0.5) * weight


static func _highest_utility_action(action_scores: Dictionary, eligible_actions: Array) -> String:
	var best_action := "idle"
	var best_score := -INF
	for action_value: Variant in eligible_actions:
		var action_id := str(action_value)
		var score := float(action_scores.get(action_id, -INF))
		if score > best_score:
			best_score = score
			best_action = action_id
	return best_action


static func _eligible_actions(observation: Dictionary) -> Array[String]:
	var eligible: Array[String] = []
	var objects_value: Variant = observation.get("nearbyObjects", [])
	var peers_value: Variant = observation.get("nearbyNorns", [])
	var objects: Array = objects_value if objects_value is Array else []
	var peers: Array = peers_value if peers_value is Array else []
	for action_id: String in ACTION_IDS:
		if action_id == "fruit" and _has_sensed_id(objects, "fruit"):
			eligible.append(action_id)
		elif action_id == "spinner" and _has_sensed_id(objects, "spinner"):
			eligible.append(action_id)
		elif action_id == "observe_peer" and _has_sensed_peer(peers):
			eligible.append(action_id)
		elif action_id == "draw" and _has_sensed_id(objects, DRAW_SURFACE_ID) and _has_sensed_id(objects, DRAW_TOOL_ID):
			eligible.append(action_id)
		elif ["rest", "idle"].has(action_id):
			eligible.append(action_id)
	return eligible


static func _has_sensed_id(sensed: Array, expected_id: String) -> bool:
	for entry_value: Variant in sensed:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("id", "")) == expected_id and bool(entry.get("available", true)):
			return true
	return false


static func _has_sensed_peer(peers: Array) -> bool:
	for peer_value: Variant in peers:
		if not (peer_value is Dictionary):
			continue
		if not str(peer_value.get("id", "")).is_empty():
			return true
	return false


static func _decision_reason(action_id: String, breakdown: Dictionary, hunger: float, glucose: float) -> String:
	var drive := float(breakdown["drive"])
	var preference := float(breakdown["combinedPreference"])
	var memory := float(breakdown["episodicMemory"])
	var strongest_preference := -INF
	for component: String in ["actionAssociation", "contextAssociation", "episodicMemory", "recurrentPolicy"]:
		strongest_preference = maxf(strongest_preference, float(breakdown[component]))
	if action_id == "fruit":
		if memory > 0.0 and memory >= strongest_preference:
			return "Remembering that fruit eased hunger before"
		if preference > drive:
			return "Learned preferences are drawing attention to fruit"
		return "Low glucose is calling for food" if 100.0 - glucose > hunger else "Hunger is drawing attention to fruit"
	if action_id == "spinner":
		if memory > 0.0 and memory >= strongest_preference:
			return "Remembering that the spinner was enjoyable"
		if preference > drive:
			return "Learned preferences are drawing attention to the spinner"
		return "Curiosity is pulling toward the spinner"
	if action_id == "rest":
		return "Learned preferences are favoring a pause" if preference > drive else "Fatigue or low energy is calling for a pause"
	if action_id == "observe_peer":
		return "Learned preferences are drawing them toward another Norn" if preference > drive else "Social attention is drawing them toward another Norn"
	if action_id == "draw":
		return "Learned preferences are favoring a mark-making visit" if preference > drive else "Curiosity is drawing attention to the mark surface"
	if preference > drive:
		return "Learned preferences are favoring a quiet moment"
	return "Their immediate needs are settled"


static func _peer_social_memory_score(state: Dictionary, peer_id: String, now: float) -> float:
	var episodes_value: Variant = state.get("episodes", [])
	if not (episodes_value is Array):
		return 0.0
	var current_time := maxf(0.0, _finite_or(now, 0.0))
	var total_weight := 0.0
	var weighted_valence := 0.0
	for episode_value: Variant in episodes_value:
		if not (episode_value is Dictionary):
			continue
		var episode: Dictionary = episode_value
		if str(episode.get("actorId", "")) != peer_id or not ["observe", "observe-feedback"].has(str(episode.get("eventType", episode.get("outcome", "")))):
			continue
		var valence_value: Variant = episode.get("valence", null)
		if not _is_finite_number(valence_value):
			continue
		var salience := clampf(_finite_or(episode.get("salience", 0.55), 0.55), 0.0, 1.0)
		var episode_time := _finite_or(episode.get("time", current_time), current_time)
		var elapsed := maxf(0.0, current_time - episode_time)
		var recency_weight := pow(0.5, elapsed / PEER_MEMORY_HALF_LIFE_SECONDS)
		var evidence_weight := salience * recency_weight
		if evidence_weight <= 0.0:
			continue
		total_weight += evidence_weight
		weighted_valence += clampf(float(valence_value), -1.0, 1.0) * evidence_weight
	if total_weight <= 0.0:
		return 0.0
	var familiarity := clampf(total_weight / PEER_MEMORY_FAMILIARITY_UNITS, 0.0, 1.0)
	var mean_valence := weighted_valence / total_weight
	return clampf(mean_valence * familiarity, -1.0, 1.0) * PEER_MEMORY_SCORE_LIMIT


static func _apply_commitment(state: Dictionary, decision: Dictionary, observation: Dictionary, persist: bool) -> Dictionary:
	var now := maxf(0.0, _finite_or(observation.get("time", 0.0), 0.0))
	var previous_value = state.get("lastDecision", null)
	var previous: Dictionary = previous_value if previous_value is Dictionary else {}
	var previous_action := str(previous.get("actionId", ""))
	var previous_is_target := ["fruit", "spinner"].has(previous_action)
	var commitment_until := float(state.get("commitmentUntil", 0.0))
	var eligible_actions: Array = decision.get("eligibleActions", [])
	var safety_override := str(decision.get("safetyOverride", ""))
	if previous_is_target and eligible_actions.has(previous_action) and safety_override.is_empty() and decision["actionId"] != previous_action and now < commitment_until:
		var next_score := float(decision["actionScores"][decision["actionId"]])
		var previous_score := float(decision["actionScores"][previous_action])
		if next_score < previous_score + 18.0:
			decision["actionId"] = previous_action
			decision["reason"] = "Continuing toward fruit while the current choice is still committed" if previous_action == "fruit" else "Continuing toward the spinner while the current choice is still committed"
	var next_is_target := ["fruit", "spinner"].has(decision["actionId"])
	if next_is_target and (not previous_is_target or decision["actionId"] != previous_action):
		commitment_until = now + 1.2
	elif not next_is_target:
		commitment_until = now
	if persist:
		state["commitmentUntil"] = commitment_until
	return decision


static func _derive_learning_delta(event_type: String, explicit_delta) -> float:
	if _is_finite_number(explicit_delta):
		return clampf(float(explicit_delta), -0.2, 0.2)
	if event_type == "food":
		return 0.12
	if event_type == "toy":
		return 0.14
	if event_type == "praise":
		return 0.2
	if event_type == "scold":
		return -0.2
	if event_type == "observe":
		return 0.07
	if event_type == "observe-feedback":
		return 0.06
	return 0.0


static func _adjust_chemistry_for_outcome(chemistry: Dictionary, event_type: String, feedback: String) -> void:
	if event_type == "food":
		chemistry["hunger"] = float(chemistry["hunger"]) - 42.0
		chemistry["glucose"] = float(chemistry["glucose"]) + 34.0
		chemistry["satiety"] = float(chemistry["satiety"]) + 38.0
		chemistry["reward"] = float(chemistry["reward"]) + 8.0
	elif event_type == "toy":
		chemistry["curiosity"] = float(chemistry["curiosity"]) - 45.0
		chemistry["reward"] = float(chemistry["reward"]) + 8.0
		chemistry["arousal"] = float(chemistry["arousal"]) - 12.0
	elif event_type == "praise":
		chemistry["reward"] = float(chemistry["reward"]) + 12.0
		chemistry["stress"] = float(chemistry["stress"]) - 6.0
	elif event_type == "scold":
		chemistry["punishment"] = float(chemistry["punishment"]) + 12.0
		chemistry["stress"] = float(chemistry["stress"]) + 8.0
	elif event_type == "observe-feedback" and feedback == "praise":
		chemistry["reward"] = float(chemistry["reward"]) + 3.0
		chemistry["stress"] = float(chemistry["stress"]) - 1.0
	elif event_type == "observe-feedback" and feedback == "scold":
		chemistry["punishment"] = float(chemistry["punishment"]) + 3.0
		chemistry["stress"] = float(chemistry["stress"]) + 2.0
	elif ["observe", "observe-feedback", "teach", "hear", "command", "word"].has(event_type):
		chemistry["socialComfort"] = float(chemistry["socialComfort"]) + 1.5
	for chemical: String in CHEMICAL_NAMES:
		chemistry[chemical] = clampf(float(chemistry[chemical]), 0.0, 100.0)


static func _valid_record(record: Dictionary) -> bool:
	var record_version := int(record.get("version", -1))
	if not [1, 2, VERSION].has(record_version):
		return false
	var allow_missing_draw := record_version < VERSION
	var seed_value = record.get("seed", null)
	var traits = record.get("traits", null)
	var chemistry = record.get("chemistry", null)
	if not _is_finite_number(seed_value) or int(seed_value) < 0 or int(seed_value) > 0xffffffff:
		return false
	if not (traits is Dictionary) or not _bounded_number(traits.get("curiosity", null), 0.0, 1.0) or not _bounded_number(traits.get("sociability", null), 0.0, 1.0):
		return false
	if not _valid_chemistry(chemistry):
		return false
	if not (record.get("actionAssociations", null) is Dictionary) or not _valid_associations(record["actionAssociations"], allow_missing_draw):
		return false
	if not (record.get("contextAssociations", null) is Dictionary) or not _valid_context_map(record["contextAssociations"], allow_missing_draw):
		return false
	if not (record.get("episodes", null) is Array) or record["episodes"].size() > EPISODE_LIMIT:
		return false
	if not _is_finite_number(record.get("nextEpisodeId", null)) or int(record["nextEpisodeId"]) < 1:
		return false
	if not (record.get("eligibility", null) is Dictionary) or not _valid_associations(record["eligibility"], allow_missing_draw):
		return false
	if not (record.get("contextEligibility", null) is Dictionary) or not _valid_context_map(record["contextEligibility"], allow_missing_draw):
		return false
	var recurrent = record.get("recurrent", null)
	if not (recurrent is Dictionary) or not (recurrent.get("hidden", null) is Array) or recurrent["hidden"].size() != RECURRENT_UNITS:
		return false
	for value in recurrent["hidden"]:
		if not _bounded_number(value, -1.0, 1.0):
			return false
	if not _is_finite_number(recurrent.get("decisionCount", null)) or int(recurrent["decisionCount"]) < 0:
		return false
	if not _bounded_number(record.get("commitmentUntil", null), 0.0, 1.0e20):
		return false
	var last_decision = record.get("lastDecision", null)
	if last_decision != null and (not (last_decision is Dictionary) or not _valid_decision(last_decision, allow_missing_draw)):
		return false
	var episode_ids := {}
	for episode in record["episodes"]:
		if not (episode is Dictionary) or not _valid_episode(episode):
			return false
		var episode_id := int(episode["id"])
		if episode_ids.has(episode_id) or episode_id >= int(record["nextEpisodeId"]):
			return false
		episode_ids[episode_id] = true
	return true


static func _valid_chemistry(chemistry) -> bool:
	if not (chemistry is Dictionary):
		return false
	for chemical: String in CHEMICAL_NAMES:
		if not _bounded_number(chemistry.get(chemical, null), 0.0, 100.0):
			return false
	return true


static func _valid_associations(associations: Dictionary, allow_missing_draw: bool = false) -> bool:
	for action_id: String in ACTION_IDS:
		if allow_missing_draw and action_id == "draw" and not associations.has("draw"):
			continue
		if not _bounded_number(associations.get(action_id, null), 0.0, 1.0):
			return false
	return true


static func _valid_context_map(context_map: Dictionary, allow_missing_draw: bool = false) -> bool:
	for action_id: String in ACTION_IDS:
		if allow_missing_draw and action_id == "draw" and not context_map.has("draw"):
			continue
		var row = context_map.get(action_id, null)
		if not (row is Dictionary):
			return false
		for context_id: String in CONTEXT_IDS:
			if not _bounded_number(row.get(context_id, null), 0.0, 1.0):
				return false
	return true


static func _valid_episode(episode: Dictionary) -> bool:
	if not _is_finite_number(episode.get("id", null)) or int(episode["id"]) < 1:
		return false
	if not _bounded_number(episode.get("time", null), 0.0, 1.0e20):
		return false
	var observation: Dictionary = episode.get("observation", {})
	if not _bounded_number(observation.get("hunger", null), 0.0, 100.0) or not _bounded_number(observation.get("curiosity", null), 0.0, 100.0):
		return false
	if not _bounded_number(observation.get("fatigue", null), 0.0, 100.0) or not _bounded_number(observation.get("peerCount", null), 0.0, 4.0):
		return false
	if not (episode.get("chemicalsBefore", null) is Dictionary) or not _valid_chemistry(episode["chemicalsBefore"]):
		return false
	if not (episode.get("chemicalsAfter", null) is Dictionary) or not _valid_chemistry(episode["chemicalsAfter"]):
		return false
	if not _bounded_number(episode.get("salience", null), 0.0, 1.0):
		return false
	if not [-1, 0, 1].has(int(episode.get("valence", 9))):
		return false
	if not (episode.get("eventType", null) is String) or not (episode.get("outcome", null) is String):
		return false
	var action_id = episode.get("actionId", null)
	if action_id != null and not ACTION_IDS.has(action_id):
		return false
	var target_id = episode.get("targetId", null)
	if target_id != null and not ["fruit", "spinner", "praise", "scold", "drawing_surface"].has(target_id):
		return false
	var actor_id = episode.get("actorId", null)
	if actor_id != null and (not (actor_id is String) or actor_id.length() > 32):
		return false
	var linked_event_id = episode.get("linkedEventId", null)
	if linked_event_id != null and (not _is_finite_number(linked_event_id) or int(linked_event_id) <= 0):
		return false
	if not (episode.get("text", null) is String) or episode["text"].length() > 500:
		return false
	var word = episode.get("word", null)
	if word != null and (not (word is String) or word.length() > 24):
		return false
	var surface_id = episode.get("surfaceId", null)
	if surface_id != null and (not (surface_id is String) or not ["drawing_surface"].has(surface_id)):
		return false
	var tool_id = episode.get("toolId", null)
	if tool_id != null and (not (tool_id is String) or not ["charcoal"].has(tool_id)):
		return false
	var stroke_data = episode.get("strokeData", null)
	if stroke_data != null and not _valid_draw_stroke_data(stroke_data):
		return false
	if str(episode.get("eventType", "")) == "draw-mark":
		if action_id != "draw" or target_id != "drawing_surface" or surface_id != "drawing_surface" or tool_id != "charcoal" or stroke_data == null:
			return false
	var feedback = episode.get("feedback", "")
	if not (feedback is String) or not ["", "praise", "scold"].has(feedback):
		return false
	var sociability = episode.get("sociability", null)
	if sociability != null and not _bounded_number(sociability, 0.0, 1.0):
		return false
	return true


static func _valid_draw_stroke_data(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var stroke: Dictionary = value
	var point_count: Variant = stroke.get("pointCount", null)
	var start: Variant = stroke.get("start", null)
	var finish: Variant = stroke.get("end", null)
	if not _is_finite_number(point_count) or int(point_count) < 1 or int(point_count) > DRAW_MAX_POINTS_PER_STROKE:
		return false
	for point_value: Variant in [start, finish]:
		if not (point_value is Dictionary):
			return false
		var point: Dictionary = point_value
		for field: String in ["x", "y", "pressure"]:
			if not _is_finite_number(point.get(field, null)) or int(point[field]) < 0 or int(point[field]) > 255:
				return false
	return true


static func _valid_decision(decision: Variant, allow_missing_draw: bool = false) -> bool:
	if not (decision is Dictionary) or not ACTION_IDS.has(decision.get("actionId", "")):
		return false
	var scores = decision.get("actionScores", null)
	if not (scores is Dictionary):
		return false
	for action_id: String in ACTION_IDS:
		if allow_missing_draw and action_id == "draw" and not scores.has("draw"):
			continue
		if not _is_finite_number(scores.get(action_id, null)):
			return false
	if not (decision.get("reason", null) is String) or decision["reason"].length() > 240:
		return false
	var recalled = decision.get("recalledEpisodeIds", null)
	if not (recalled is Array) or recalled.size() > 3:
		return false
	for episode_id in recalled:
		if not _is_finite_number(episode_id) or int(episode_id) < 1:
			return false
	var components = decision.get("components", null)
	if not (components is Dictionary):
		return false
	for component in ["fruitNeed", "fruitHabit", "fruitContext", "fruitScore", "spinnerNeed", "spinnerHabit", "spinnerContext", "spinnerScore", "restNeed", "observeNeed"]:
		if not _is_finite_number(components.get(component, null)):
			return false
	if (not allow_missing_draw or components.has("drawNeed")) and not _is_finite_number(components.get("drawNeed", null)):
		return false
	return true


static func _trace_order(action_id: String) -> Array[String]:
	var order: Array[String] = []
	if not action_id.is_empty():
		order.append(action_id)
	for id: String in ACTION_IDS:
		if id != action_id:
			order.append(id)
	return order


static func _make_actionless_chemical_map() -> Dictionary:
	var result := {}
	for chemical: String in CHEMICAL_NAMES:
		result[chemical] = 0.0
	return result


static func _normalized(value: float) -> float:
	return clampf(_finite_or(value, 0.0), 0.0, 100.0) / 100.0


static func _finite_or(value, fallback: float) -> float:
	return float(value) if _is_finite_number(value) else fallback


static func _is_finite_number(value) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))


static func _bounded_number(value, low: float, high: float) -> bool:
	return _is_finite_number(value) and float(value) >= low and float(value) <= high
