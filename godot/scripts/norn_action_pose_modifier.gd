class_name NornActionPoseModifier
extends SkeletonModifier3D

const ACTION_DURATION := 0.9
const ACTION_IDS: Array[String] = ["eat", "forage", "drink", "play"]

var _active_action_id := ""
var _elapsed := 0.0


func play_action(action_id: String) -> bool:
	if not ACTION_IDS.has(action_id):
		return false
	_active_action_id = action_id
	_elapsed = 0.0
	active = true
	influence = 0.0
	return true


func cancel_action() -> void:
	_active_action_id = ""
	_elapsed = ACTION_DURATION
	influence = 0.0
	active = false


func get_active_action_id() -> String:
	return _active_action_id


func _process_modification_with_delta(delta: float) -> void:
	if _active_action_id.is_empty():
		influence = 0.0
		return
	_elapsed += maxf(delta, 0.0)
	var progress := clampf(_elapsed / ACTION_DURATION, 0.0, 1.0)
	if progress >= 1.0:
		cancel_action()
		return
	influence = sin(progress * PI)
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	var pose_offsets := _pose_offsets(_active_action_id, progress)
	for bone_name: String in pose_offsets:
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index < 0:
			continue
		var pose_offset: Vector3 = pose_offsets[bone_name]
		var base_rotation := skeleton.get_bone_pose_rotation(bone_index)
		skeleton.set_bone_pose_rotation(bone_index, base_rotation * Quaternion.from_euler(pose_offset))


func _pose_offsets(action_id: String, progress: float) -> Dictionary:
	var small_bob := sin(progress * TAU * 2.0) * deg_to_rad(3.0)
	match action_id:
		"eat":
			return {
				"head": Vector3(deg_to_rad(20.0) + small_bob, 0.0, 0.0),
				"neck": Vector3(deg_to_rad(8.0), 0.0, 0.0),
				"arm_upper.R": Vector3(deg_to_rad(-28.0), 0.0, deg_to_rad(-18.0)),
				"arm_lower.R": Vector3(deg_to_rad(38.0), 0.0, 0.0),
			}
		"forage":
			return {
				"head": Vector3(deg_to_rad(25.0) + small_bob, 0.0, 0.0),
				"neck": Vector3(deg_to_rad(12.0), 0.0, 0.0),
				"chest": Vector3(deg_to_rad(8.0), 0.0, 0.0),
			}
		"drink":
			return {
				"head": Vector3(deg_to_rad(28.0) + small_bob, 0.0, 0.0),
				"neck": Vector3(deg_to_rad(14.0), 0.0, 0.0),
				"arm_upper.R": Vector3(deg_to_rad(-10.0), 0.0, deg_to_rad(-7.0)),
			}
		"play":
			var tap := sin(progress * TAU * 3.0) * deg_to_rad(16.0)
			return {
				"head": Vector3(deg_to_rad(-4.0) + small_bob, 0.0, 0.0),
				"arm_upper.R": Vector3(deg_to_rad(-22.0) + tap, 0.0, deg_to_rad(-10.0)),
				"arm_lower.R": Vector3(deg_to_rad(28.0) - tap, 0.0, 0.0),
				"arm_upper.L": Vector3(deg_to_rad(8.0) - tap * 0.4, 0.0, deg_to_rad(4.0)),
				"arm_lower.L": Vector3(deg_to_rad(-9.0), 0.0, 0.0),
			}
	return {}
