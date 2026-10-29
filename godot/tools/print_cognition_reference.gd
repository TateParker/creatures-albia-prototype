extends SceneTree

const Cognition = preload("res://scripts/norn_cognition.gd")
const FIXTURE_PATH := "res://scenarios/browser_reference.json"


func _init() -> void:
	var file := FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	if file == null:
		push_error("Cannot open browser cognition reference: %s" % FIXTURE_PATH)
		quit(1)
		return
	var fixture = JSON.parse_string(file.get_as_text())
	if not (fixture is Dictionary):
		push_error("Browser cognition reference is not valid JSON")
		quit(1)
		return
	var state: Dictionary = Cognition.create_state(int(fixture["seed"]), fixture["traits"], fixture["initial"])
	var decisions: Array[Dictionary] = []
	var outcomes: Array[Dictionary] = []
	var decision_steps: Array = fixture["steps"]["decisions"]
	var outcome_steps: Array = fixture["steps"]["outcomes"]
	decisions.append({"label": decision_steps[0]["label"], "actual": Cognition.decide(state, _observation(state, fixture, 0.0))})
	outcomes.append({"label": outcome_steps[0]["label"], "actual": Cognition.record_outcome(state, outcome_steps[0]["input"])})
	decisions.append({"label": decision_steps[1]["label"], "actual": Cognition.decide(state, _observation(state, fixture, 1.2))})
	outcomes.append({"label": outcome_steps[1]["label"], "actual": Cognition.record_outcome(state, outcome_steps[1]["input"])})
	decisions.append({"label": decision_steps[2]["label"], "actual": Cognition.decide(state, _observation(state, fixture, 2.2))})
	outcomes.append({"label": outcome_steps[2]["label"], "actual": Cognition.record_outcome(state, outcome_steps[2]["input"])})
	var saved_json := JSON.stringify(Cognition.serialize_state(state))
	var restored_record = JSON.parse_string(saved_json)
	var restored: Dictionary = Cognition.restore_state(restored_record)
	if restored.is_empty():
		push_error("Cognition state could not be restored from the JSON round trip")
		quit(1)
		return
	decisions.append({"label": decision_steps[3]["label"], "actual": Cognition.decide(restored, _observation(restored, fixture, 3.2))})
	var output := {
		"version": 1,
		"description": "Actual GDScript output for manual comparison with browser_reference.json.",
		"seed": fixture["seed"],
		"decisions": decisions,
		"outcomes": outcomes,
		"finalState": {
			"chemistry": restored["chemistry"],
			"actionAssociations": restored["actionAssociations"],
			"contextAssociations": restored["contextAssociations"],
			"episodes": _summarize_episodes(restored["episodes"]),
			"nextEpisodeId": restored["nextEpisodeId"],
			"decisionCount": restored["decisionCount"]
		}
	}
	print(JSON.stringify(output, "\t"))
	quit(0)


func _observation(state: Dictionary, fixture: Dictionary, time: float) -> Dictionary:
	return {
		"time": time,
		"chemistry": state["chemistry"],
		"nearbyObjects": fixture["nearbyObjects"],
		"nearbyNorns": [],
		"guidance": null,
		"languageSignals": {}
	}


func _summarize_episodes(episodes: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for episode: Dictionary in episodes:
		result.append({
			"id": episode["id"],
			"time": episode["time"],
			"actionId": episode["actionId"],
			"targetId": episode["targetId"],
			"eventType": episode["eventType"],
			"salience": episode["salience"],
			"valence": episode["valence"]
		})
	return result
