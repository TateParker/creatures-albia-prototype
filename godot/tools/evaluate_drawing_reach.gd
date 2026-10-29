extends SceneTree

const Evaluator := preload("res://scripts/drawing_reach_evaluator.gd")
const SEEDS: Array[int] = [9901, 9902, 9903, 9904, 9905]


func _initialize() -> void:
	call_deferred("_run_baseline")


func _run_baseline() -> void:
	var result: Dictionary = Evaluator.run_baseline(SEEDS)
	if result.is_empty():
		push_error("DRAWING_REACH_BASELINE_FAILED: evaluator did not return five seed results")
		quit(1)
		return
	for seed_result: Dictionary in result["seeds"]:
		print("DRAWING_REACH_SEED seed=%d trials=%d median_error_pixels=%.6f hit_rate_percent=%.2f" % [
			int(seed_result["seed"]),
			int(seed_result["trialCount"]),
			float(seed_result["medianErrorPixels"]),
			float(seed_result["hitRate"]) * 100.0
		])
	print("DRAWING_REACH_BASELINE seeds=%d trials_per_seed=%d decisions_per_trial=%d interval_sim_seconds=%.1f median_error_pixels=%.6f median_hit_rate_percent=%.2f" % [
		int(result["seedCount"]),
		int(result["trialsPerSeed"]),
		Evaluator.DECISIONS_PER_TRIAL,
		Evaluator.DECISION_INTERVAL_SECONDS,
		float(result["medianErrorPixels"]),
		float(result["medianHitRate"]) * 100.0
	])
	quit()
