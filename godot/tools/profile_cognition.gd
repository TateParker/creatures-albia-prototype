extends SceneTree

const Cognition = preload("res://scripts/norn_cognition.gd")


func _initialize() -> void:
	_profile()
	quit()


func _profile() -> void:
	var cognition := Cognition.create_state(4181996, {"curiosity": 0.65, "sociability": 0.55}, {
		"hunger": 45.0,
		"curiosity": 45.0,
		"fatigue": 18.0
	})
	var observation := {
		"time": 0.0,
		"chemistry": cognition["chemistry"],
		"nearbyObjects": [
			{"id": "fruit", "kind": "food", "label": "Honey fruit", "distance": 350.0, "affordances": ["eat"]},
			{"id": "spinner", "kind": "toy", "label": "Wind-up spinner", "distance": 620.0, "affordances": ["play"]}
		],
		"nearbyNorns": [],
		"guidance": null,
		"languageSignals": {}
	}
	var chemistry_us: Array[float] = []
	var decision_us: Array[float] = []
	for tick in range(1000):
		var before_chemistry := Time.get_ticks_usec()
		Cognition.advance_chemistry(cognition, {"active": 0.5}, 0.1)
		chemistry_us.append(float(Time.get_ticks_usec() - before_chemistry))
		if tick % 2 == 0:
			observation["time"] = float(tick) / 10.0
			observation["chemistry"] = cognition["chemistry"]
			var before_decision := Time.get_ticks_usec()
			Cognition.decide(cognition, observation)
			decision_us.append(float(Time.get_ticks_usec() - before_decision))

	print("Godot: %s" % Engine.get_version_info()["string"])
	print("Cognition-only profile: fixed seed, two visible interactables, 1000 chemistry steps and 500 decisions")
	print("Chemistry 10 Hz calls: %s μs" % _summary(chemistry_us))
	print("Decision 5 Hz calls: %s μs" % _summary(decision_us))


func _summary(samples: Array[float]) -> String:
	var sorted: Array[float] = samples.duplicate()
	sorted.sort()
	if sorted.is_empty():
		return "no samples"
	var median := sorted[int((sorted.size() - 1) * 0.5)]
	var p95 := sorted[clampi(int(ceil(float(sorted.size() - 1) * 0.95)), 0, sorted.size() - 1)]
	return "median %.3f, p95 %.3f, max %.3f" % [median, p95, sorted[-1]]
