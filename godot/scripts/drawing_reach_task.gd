class_name DrawingReachTask
extends RefCounted

const START_UV := Vector2(0.5, 0.5)
const TARGET_RADIUS_UV := 0.24
const TARGET_COUNT := 8
const TARGET_DELTA_SCALE_UV := 0.25
const SURFACE_PIXEL_INTERVALS := 255.0
const HIT_RADIUS_PIXELS := 8.0


static func target_uv_for_direction(direction_index: int) -> Variant:
	if direction_index < 0 or direction_index >= TARGET_COUNT:
		return null
	var direction_angle := TAU * float(direction_index) / float(TARGET_COUNT)
	var target_uv := START_UV + Vector2.RIGHT.rotated(direction_angle) * TARGET_RADIUS_UV
	return target_uv if _valid_uv(target_uv) else null


static func build_balanced_trial_order(direction_indices: Array[int], repetitions_per_direction: int, seed: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if direction_indices.is_empty() or repetitions_per_direction <= 0:
		return result
	var seen_directions := {}
	for direction_index: int in direction_indices:
		if direction_index < 0 or direction_index >= TARGET_COUNT or seen_directions.has(direction_index):
			return result
		seen_directions[direction_index] = true
	for direction_index: int in direction_indices:
		var target_uv: Variant = target_uv_for_direction(direction_index)
		if not (target_uv is Vector2):
			return []
		for repeat_index: int in range(repetitions_per_direction):
			result.append({
				"directionIndex": direction_index,
				"repeatIndex": repeat_index,
				"targetUv": target_uv
			})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for index: int in range(result.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var entry: Dictionary = result[index]
		result[index] = result[swap_index]
		result[swap_index] = entry
	return result


static func normalized_target_delta(cursor_uv: Vector2, target_uv: Vector2) -> Variant:
	if not _valid_uv(cursor_uv) or not _valid_uv(target_uv):
		return null
	var delta := (target_uv - cursor_uv) / TARGET_DELTA_SCALE_UV
	return Vector2(clampf(delta.x, -1.0, 1.0), clampf(delta.y, -1.0, 1.0))


static func score_endpoint(final_uv: Vector2, target_uv: Vector2) -> Dictionary:
	if not _valid_uv(final_uv) or not _valid_uv(target_uv):
		return {}
	var error_pixels := final_uv.distance_to(target_uv) * SURFACE_PIXEL_INTERVALS
	return {"errorPixels": error_pixels, "hit": error_pixels <= HIT_RADIUS_PIXELS}


static func _valid_uv(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y) and value.x >= 0.0 and value.x <= 1.0 and value.y >= 0.0 and value.y <= 1.0
