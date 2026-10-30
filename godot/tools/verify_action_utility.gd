extends SceneTree

const Cognition = preload("res://scripts/norn_cognition.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	test_settled_needs_keep_idle_as_a_candidate()
	test_untrained_curiosity_can_choose_a_sensed_spinner()
	test_legacy_uncentered_associations_migrate_to_neutral_baseline()
	test_centered_learned_preference_can_redirect_a_close_choice()
	test_action_scores_have_bounded_explanations()
	test_live_diagnostics_do_not_change_saved_decision_shape()
	test_urgent_need_threshold_boundaries()
	test_safety_override_bypasses_target_commitment()
	test_simultaneous_safety_uses_need_severity_and_stable_ties()
	test_ineligible_targets_and_peers_are_not_candidates()
	test_commitment_cannot_restore_a_missing_target()
	test_missing_urgent_target_uses_deterministic_fallback()
	if _failures.is_empty():
		print("ACTION_UTILITY_CHECKS_OK cases=ordinary,legacy-associations,safety,eligibility,commitment")
		quit(0)
		return
	for failure: String in _failures:
		push_error("ACTION_UTILITY_CHECK_FAILED: " + failure)
	push_error("ACTION_UTILITY_CHECKS_FAILED task=ordinary failures=%d" % _failures.size())
	quit(1)


func test_settled_needs_keep_idle_as_a_candidate() -> void:
	var state := Cognition.create_state(7301, {"curiosity": 0.5, "sociability": 0.1}, {
		"hunger": 10.0,
		"curiosity": 5.0,
		"fatigue": 5.0
	})
	var decision: Dictionary = Cognition.preview(state, _observation(state))
	_expect(str(decision.get("actionId", "")) == "idle", "settled needs without sensed opportunities select idle")
	_expect((decision.get("eligibleActions", []) as Array).has("idle"), "idle remains eligible when needs are settled")


func test_untrained_curiosity_can_choose_a_sensed_spinner() -> void:
	var state := Cognition.create_state(4181996, {"curiosity": 0.65, "sociability": 0.55}, {
		"hunger": 10.0,
		"curiosity": 44.4,
		"fatigue": 18.0
	})
	var decision: Dictionary = Cognition.preview(state, _observation(state, [{"id": "spinner", "distance": 6.75}], []))
	_expect(is_equal_approx(float(state["actionAssociations"]["spinner"]), 0.5), "an untrained spinner association begins at the neutral midpoint")
	_expect(str(decision.get("actionId", "")) == "spinner", "untrained but expressed curiosity can beat settled idle utility")
	_expect(float(decision.get("actionScores", {}).get("spinner", 0.0)) > float(decision.get("actionScores", {}).get("idle", 0.0)), "curiosity utility is not erased by a missing learned association")


func test_legacy_uncentered_associations_migrate_to_neutral_baseline() -> void:
	var record := Cognition.serialize_state(Cognition.create_state(4181996))
	record["version"] = 1
	record["actionAssociations"] = {"fruit": 0.0, "spinner": 0.25, "rest": 0.5, "observe_peer": 0.75, "idle": 1.0}
	var restored: Dictionary = Cognition.restore_state(record)
	_expect(not restored.is_empty(), "an existing cognition version-1 state remains restorable")
	if restored.is_empty():
		return
	var expected := {
		"fruit": 0.5, "spinner": 0.625, "rest": 0.75, "observe_peer": 0.875,
		"idle": 1.0, "draw": 0.5, "forage": 0.5, "drink": 0.5, "explore": 0.5
	}
	for action_id: String in Cognition.get_action_ids():
		_expect(expected.has(action_id), "legacy %s action has an explicit migration expectation" % action_id)
		_expect(is_equal_approx(float(restored["actionAssociations"][action_id]), float(expected.get(action_id, -1.0))), "legacy %s association maps from a zero baseline" % action_id)


func test_centered_learned_preference_can_redirect_a_close_choice() -> void:
	var traits := {"curiosity": 0.5, "sociability": 0.1}
	var needs := {"hunger": 10.0, "curiosity": 35.0, "fatigue": 5.0}
	var neutral_state := Cognition.create_state(7302, traits, needs)
	var preference_state := Cognition.create_state(7302, traits, {
		"hunger": needs["hunger"],
		"curiosity": needs["curiosity"],
		"fatigue": needs["fatigue"],
		"actionAssociations": {"spinner": 1.0}
	})
	var observation := _observation(neutral_state, [{"id": "spinner", "distance": 1.0}], [])
	var neutral_decision: Dictionary = Cognition.preview(neutral_state, observation)
	var preferred_decision: Dictionary = Cognition.preview(preference_state, observation)
	_expect(str(neutral_decision.get("actionId", "")) == "idle", "a weak spinner drive stays settled before strong learning")
	_expect(str(preferred_decision.get("actionId", "")) == "spinner", "a strong non-critical spinner association can redirect the close choice")


func test_action_scores_have_bounded_explanations() -> void:
	var state := Cognition.create_state(7303, {"curiosity": 0.8, "sociability": 0.7}, {
		"hunger": 89.0,
		"curiosity": 100.0,
		"fatigue": 94.0,
		"actionAssociations": {"fruit": 1.0, "spinner": 1.0, "rest": 1.0, "observe_peer": 1.0, "idle": 1.0}
	})
	var objects := [
		{"id": "fruit", "kind": "food", "distance": 1.0},
		{"id": "spinner", "kind": "toy", "distance": 2.0}
	]
	var peers := [{"id": "mallow", "distance": 1.0}]
	var observation := _observation(state, objects, peers)
	var decision: Dictionary = Cognition.preview(state, observation)
	var scores_value: Variant = decision.get("actionScores", null)
	var breakdown_value: Variant = decision.get("scoreBreakdown", null)
	_expect(scores_value is Dictionary and (scores_value as Dictionary).size() == Cognition.get_action_ids().size(), "utility scores include every action")
	_expect(breakdown_value is Dictionary and (breakdown_value as Dictionary).size() == Cognition.get_action_ids().size(), "the live decision explains each action")
	if not (scores_value is Dictionary):
		return
	var scores: Dictionary = scores_value
	var breakdown: Dictionary = breakdown_value if breakdown_value is Dictionary else {}
	for action_id: String in Cognition.get_action_ids():
		var score: Variant = scores.get(action_id, null)
		_expect(_is_finite_number(score), "%s has a finite utility score" % action_id)
		if _is_finite_number(score):
			_expect(float(score) >= 0.0 and float(score) <= 100.0, "%s utility stays within [0, 100]" % action_id)
		var action_breakdown_value: Variant = breakdown.get(action_id, null)
		_expect(action_breakdown_value is Dictionary, "%s has a score breakdown" % action_id)
		if not (action_breakdown_value is Dictionary):
			continue
		var action_breakdown: Dictionary = action_breakdown_value
		for component: String in ["drive", "actionAssociation", "contextAssociation", "episodicMemory", "recurrentPolicy", "finalUtility"]:
			_expect(_is_finite_number(action_breakdown.get(component, null)), "%s exposes finite %s contribution" % [action_id, component])
		if _is_finite_number(score) and _is_finite_number(action_breakdown.get("finalUtility", null)):
			_expect(is_equal_approx(float(score), float(action_breakdown["finalUtility"])), "%s action score equals its final utility breakdown" % action_id)
	_expect(str(decision.get("safetyOverride", "")) == "", "ordinary preview reports no safety override")
	var repeated: Dictionary = Cognition.preview(state, observation)
	_expect(decision.get("actionId", "") == repeated.get("actionId", ""), "equivalent previews select the same action")
	_expect(decision.get("actionScores", {}) == repeated.get("actionScores", {}), "equivalent previews produce the same scores")
	if decision.get("scoreBreakdown", null) is Dictionary and repeated.get("scoreBreakdown", null) is Dictionary:
		_expect(decision["scoreBreakdown"] == repeated["scoreBreakdown"], "equivalent previews produce the same explanation")


func test_live_diagnostics_do_not_change_saved_decision_shape() -> void:
	var state := Cognition.create_state(7304, {"curiosity": 0.5, "sociability": 0.4}, {
		"hunger": 10.0,
		"curiosity": 5.0,
		"fatigue": 5.0
	})
	var decision: Dictionary = Cognition.decide(state, _observation(state))
	for diagnostic: String in ["eligibleActions", "scoreBreakdown", "safetyOverride"]:
		_expect(decision.has(diagnostic), "live decision includes %s diagnostics" % diagnostic)
	var saved_decision: Dictionary = state.get("lastDecision", {})
	for diagnostic: String in ["eligibleActions", "scoreBreakdown", "safetyOverride"]:
		_expect(not saved_decision.has(diagnostic), "persisted lastDecision omits transient %s diagnostics" % diagnostic)
	var serialized: Dictionary = Cognition.serialize_state(state)
	var restored: Dictionary = Cognition.restore_state(serialized)
	_expect(not restored.is_empty(), "a decision with transient diagnostics remains restorable")
	var restored_decision: Dictionary = restored.get("lastDecision", {})
	_expect(restored_decision.has("actionScores") and restored_decision.has("components"), "restored lastDecision retains its established fields")
	for diagnostic: String in ["eligibleActions", "scoreBreakdown", "safetyOverride"]:
		_expect(not restored_decision.has(diagnostic), "serialized decision shape excludes %s" % diagnostic)


func test_urgent_need_threshold_boundaries() -> void:
	var fruit_objects := [{"id": "fruit", "distance": 1.0}]
	var hunger_below := _state_with_chemistry(7310, 89.0, 80.0, 5.0, 94.0)
	var hunger_at := _state_with_chemistry(7311, 90.0, 80.0, 5.0, 94.0)
	var glucose_above := _state_with_chemistry(7312, 20.0, 11.0, 5.0, 94.0)
	var glucose_at := _state_with_chemistry(7313, 20.0, 10.0, 5.0, 94.0)
	var fatigue_below := _state_with_chemistry(7314, 20.0, 80.0, 5.0, 94.0)
	var fatigue_at := _state_with_chemistry(7315, 20.0, 80.0, 5.0, 95.0)
	var hunger_below_decision: Dictionary = Cognition.preview(hunger_below, _observation(hunger_below, fruit_objects))
	var hunger_at_decision: Dictionary = Cognition.preview(hunger_at, _observation(hunger_at, fruit_objects))
	var glucose_above_decision: Dictionary = Cognition.preview(glucose_above, _observation(glucose_above, fruit_objects))
	var glucose_at_decision: Dictionary = Cognition.preview(glucose_at, _observation(glucose_at, fruit_objects))
	var fatigue_below_decision: Dictionary = Cognition.preview(fatigue_below, _observation(fatigue_below))
	var fatigue_at_decision: Dictionary = Cognition.preview(fatigue_at, _observation(fatigue_at))
	_expect(str(hunger_below_decision.get("safetyOverride", "")) == "", "hunger 89 is below the fruit safety boundary")
	_expect(str(hunger_at_decision.get("safetyOverride", "")) == "fruit", "hunger 90 reaches the fruit safety boundary")
	_expect(str(glucose_above_decision.get("safetyOverride", "")) == "", "glucose 11 is above the fruit safety boundary")
	_expect(str(glucose_at_decision.get("safetyOverride", "")) == "fruit", "glucose 10 reaches the fruit safety boundary")
	_expect(str(fatigue_below_decision.get("safetyOverride", "")) == "", "fatigue 94 is below the rest safety boundary")
	_expect(str(fatigue_at_decision.get("safetyOverride", "")) == "rest", "fatigue 95 reaches the rest safety boundary")


func test_safety_override_bypasses_target_commitment() -> void:
	var available_objects := [
		{"id": "fruit", "distance": 1.0},
		{"id": "spinner", "distance": 2.0}
	]
	var spinner_state := _state_with_chemistry(7320, 10.0, 90.0, 100.0, 5.0, {"curiosity": 1.0})
	var initial_spinner: Dictionary = Cognition.decide(spinner_state, _observation(spinner_state, available_objects, [], 1.0))
	_expect(str(initial_spinner.get("actionId", "")) == "spinner", "high curiosity establishes a live spinner commitment")
	var urgent_chemistry: Dictionary = spinner_state["chemistry"].duplicate(true)
	urgent_chemistry["hunger"] = 90.0
	urgent_chemistry["glucose"] = 10.0
	spinner_state["chemistry"] = urgent_chemistry
	var urgent_fruit: Dictionary = Cognition.decide(spinner_state, _observation(spinner_state, available_objects, [], 1.5))
	_expect(str(urgent_fruit.get("actionId", "")) == "fruit", "urgent hunger replaces a committed spinner target")
	_expect(str(urgent_fruit.get("safetyOverride", "")) == "fruit", "the fruit choice is marked as a safety override")

	var fruit_state := _state_with_chemistry(7321, 85.0, 15.0, 5.0, 5.0)
	var initial_fruit: Dictionary = Cognition.decide(fruit_state, _observation(fruit_state, available_objects, [], 2.0))
	_expect(str(initial_fruit.get("actionId", "")) == "fruit", "high hunger establishes a live fruit commitment")
	var urgent_rest_chemistry: Dictionary = fruit_state["chemistry"].duplicate(true)
	urgent_rest_chemistry["fatigue"] = 95.0
	fruit_state["chemistry"] = urgent_rest_chemistry
	var urgent_rest: Dictionary = Cognition.decide(fruit_state, _observation(fruit_state, available_objects, [], 2.5))
	_expect(str(urgent_rest.get("actionId", "")) == "rest", "extreme fatigue replaces a committed fruit target")
	_expect(str(urgent_rest.get("safetyOverride", "")) == "rest", "the rest choice is marked as a safety override")
	_expect(str(urgent_rest.get("reason", "")).to_lower().contains("urgent") or str(urgent_rest.get("reason", "")).to_lower().contains("fatigue"), "the rest reason explains the safety drive")


func test_simultaneous_safety_uses_need_severity_and_stable_ties() -> void:
	var fruit_greater := _state_with_chemistry(7330, 98.0, 100.0, 5.0, 96.0)
	var rest_greater := _state_with_chemistry(7331, 91.0, 100.0, 5.0, 99.0)
	var exact_tie := _state_with_chemistry(7332, 95.0, 100.0, 5.0, 97.5)
	var fruit_objects := [{"id": "fruit", "distance": 1.0}]
	var fruit_result: Dictionary = Cognition.preview(fruit_greater, _observation(fruit_greater, fruit_objects))
	var rest_result: Dictionary = Cognition.preview(rest_greater, _observation(rest_greater, fruit_objects))
	var tie_result: Dictionary = Cognition.preview(exact_tie, _observation(exact_tie, fruit_objects))
	_expect(str(fruit_result.get("safetyOverride", "")) == "fruit", "greater fruit urgency wins the simultaneous safety choice")
	_expect(str(rest_result.get("safetyOverride", "")) == "rest", "greater rest urgency wins the simultaneous safety choice")
	_expect(str(tie_result.get("safetyOverride", "")) == "fruit", "the fixed action order resolves an exact fruit/rest safety tie")


func test_ineligible_targets_and_peers_are_not_candidates() -> void:
	var state := _state_with_chemistry(7340, 100.0, 0.0, 100.0, 5.0, {"curiosity": 1.0, "sociability": 1.0}, {
		"fruit": 1.0,
		"spinner": 1.0,
		"observe_peer": 1.0
	})
	var no_targets: Dictionary = Cognition.preview(state, _observation(state))
	var unavailable_objects := [
		{"id": "fruit", "available": false},
		{"id": "spinner", "available": false}
	]
	var unavailable: Dictionary = Cognition.preview(state, _observation(state, unavailable_objects))
	for decision: Dictionary in [no_targets, unavailable]:
		var eligible: Array = decision.get("eligibleActions", [])
		_expect(not eligible.has("fruit"), "fruit without an available sensed target is ineligible")
		_expect(not eligible.has("spinner"), "spinner without an available sensed target is ineligible")
		_expect(not eligible.has("observe_peer"), "peer observation without a sensed peer is ineligible")
		_expect(not ["fruit", "spinner", "observe_peer"].has(str(decision.get("actionId", ""))), "an ineligible target action is never selected")


func test_commitment_cannot_restore_a_missing_target() -> void:
	var state := _state_with_chemistry(7350, 10.0, 90.0, 100.0, 5.0, {"curiosity": 1.0})
	var initial: Dictionary = Cognition.decide(state, _observation(state, [{"id": "spinner", "distance": 1.0}], [], 1.0))
	_expect(str(initial.get("actionId", "")) == "spinner", "spinner is selected while its target is sensed")
	var missing: Dictionary = Cognition.decide(state, _observation(state, [], [], 1.5))
	_expect(not (missing.get("eligibleActions", []) as Array).has("spinner"), "a disappeared spinner target is removed from candidates")
	_expect(str(missing.get("actionId", "")) != "spinner", "commitment does not restore a disappeared spinner target")


func test_missing_urgent_target_uses_deterministic_fallback() -> void:
	var state := _state_with_chemistry(7360, 100.0, 0.0, 5.0, 5.0)
	var observation := _observation(state)
	var first: Dictionary = Cognition.preview(state, observation)
	var second: Dictionary = Cognition.preview(state, observation)
	_expect(str(first.get("actionId", "")) == "idle", "without food or another eligible opportunity, urgent hunger falls back to idle")
	_expect(str(first.get("safetyOverride", "")) == "", "an unavailable urgent target is not reported as enacted")
	_expect(first.get("actionId", "") == second.get("actionId", ""), "missing-target fallback is deterministic")
	_expect(first.get("actionScores", {}) == second.get("actionScores", {}), "missing-target fallback preserves identical score diagnostics")


func _state_with_chemistry(seed: int, hunger: float, glucose: float, curiosity: float, fatigue: float, traits: Dictionary = {}, associations: Dictionary = {}) -> Dictionary:
	var state := Cognition.create_state(seed, traits, {
		"hunger": hunger,
		"curiosity": curiosity,
		"fatigue": fatigue,
		"actionAssociations": associations
	})
	var chemistry: Dictionary = state["chemistry"].duplicate(true)
	chemistry["glucose"] = glucose
	state["chemistry"] = chemistry
	return state


func _observation(state: Dictionary, objects: Array = [], peers: Array = [], time: float = 1.0) -> Dictionary:
	return {
		"time": time,
		"chemistry": (state["chemistry"] as Dictionary).duplicate(true),
		"nearbyObjects": objects,
		"nearbyNorns": peers
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _is_finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))
