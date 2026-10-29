extends SceneTree

const NornActorScript = preload("res://scripts/norn_actor.gd")
const TEST_BODY_COLOR := Color(0.56, 0.31, 0.19)

var _failures: Array[String] = []
var _actor: Node


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	_actor = NornActorScript.new()
	_actor.configure_identity("face-check", "Face Check", TEST_BODY_COLOR)
	root.add_child(_actor)
	await process_frame
	test_face_features_follow_head_surface()
	test_eye_pairs_are_symmetric_and_aligned()
	test_face_parts_follow_life_stage_visual_root()
	test_face_materials_follow_body_color()
	test_ear_roots_overlap_head()
	test_inner_ear_pads_overlap_outer_ears()
	test_ear_pairs_are_mirrored()
	test_ear_tip_height_preserved()
	_actor.free()
	if _failures.is_empty():
		print("FACE_GEOMETRY_CHECKS_OK")
		quit(0)
		return
	push_error("FACE_GEOMETRY_CHECKS_FAILED")
	for failure: String in _failures:
		push_error("- " + failure)
	quit(1)


func test_face_features_follow_head_surface() -> void:
	var head := _mesh("Head")
	_expect(head != null, "Head mesh exists")
	if head == null:
		return
	var surface_bounds := {
		"LeftEyeSocket": 0.06,
		"RightEyeSocket": 0.06,
		"LeftEye": 0.08,
		"RightEye": 0.08,
		"LeftEyelid": 0.08,
		"RightEyelid": 0.08,
		"Nose": 0.10
	}
	for feature_name: String in surface_bounds:
		var feature := _mesh(feature_name)
		_expect(feature != null, "%s mesh exists" % feature_name)
		if feature == null:
			continue
		var surface_z := _head_front_z(head, feature.position.x, feature.position.y)
		var offset := absf(feature.position.z - surface_z)
		_expect(offset <= float(surface_bounds[feature_name]), "%s stays within %.2f of the head surface (got %.3f)" % [feature_name, float(surface_bounds[feature_name]), offset])


func test_eye_pairs_are_symmetric_and_aligned() -> void:
	var left_eye := _mesh("LeftEye")
	var right_eye := _mesh("RightEye")
	var left_pupil := _mesh("LeftPupil")
	var right_pupil := _mesh("RightPupil")
	_expect(left_eye != null and right_eye != null, "both eye whites exist")
	_expect(left_pupil != null and right_pupil != null, "both pupils exist")
	if left_eye == null or right_eye == null or left_pupil == null or right_pupil == null:
		return
	_expect(absf(left_eye.position.x + right_eye.position.x) <= 0.001, "eye whites are mirrored across the head center")
	_expect(absf(left_eye.position.y - right_eye.position.y) <= 0.001, "eye whites share a height")
	_expect(absf(left_eye.position.z - right_eye.position.z) <= 0.001, "eye whites share a surface depth")
	_expect(absf(left_pupil.position.x + right_pupil.position.x) <= 0.001, "pupils are mirrored across the head center")
	for pair: Array in [[left_eye, left_pupil, "Left"], [right_eye, right_pupil, "Right"]]:
		var eye: MeshInstance3D = pair[0]
		var pupil: MeshInstance3D = pair[1]
		var side := str(pair[2])
		var eye_radius_x := _sphere_radius_x(eye)
		_expect(absf(pupil.position.x - eye.position.x) < eye_radius_x, "%s pupil stays inside its eye horizontally" % side)
		_expect(absf(pupil.position.y - eye.position.y) < eye.scale.y * 0.5, "%s pupil stays inside its eye vertically" % side)
		var forward_delta := eye.position.z - pupil.position.z
		_expect(forward_delta > 0.0 and forward_delta <= 0.07, "%s pupil sits slightly forward of its eye (got %.3f)" % [side, forward_delta])


func test_face_parts_follow_life_stage_visual_root() -> void:
	var visuals := _actor.get_node_or_null("LifeStageVisuals") as Node3D
	_expect(visuals != null, "LifeStageVisuals root exists")
	if visuals == null:
		return
	for feature_name: String in ["LeftEyeSocket", "RightEyeSocket", "LeftEye", "RightEye", "LeftPupil", "RightPupil", "LeftEyelid", "RightEyelid", "Nose", "LeftEar", "RightEar", "LeftEarInner", "RightEarInner"]:
		var feature := _mesh(feature_name)
		_expect(feature != null and feature.get_parent() == visuals, "%s scales with LifeStageVisuals" % feature_name)
	_actor.set_life_stage("child")
	_expect(visuals.scale.is_equal_approx(Vector3.ONE * 0.70), "child stage scales the complete visual root uniformly")
	_actor.set_life_stage("adult")
	_expect(visuals.scale.is_equal_approx(Vector3.ONE), "adult stage restores the complete visual root scale")


func test_face_materials_follow_body_color() -> void:
	var socket := _mesh("LeftEyeSocket")
	_expect(socket != null, "left eye socket exists for body-color check")
	if socket == null:
		return
	var material := socket.material_override as StandardMaterial3D
	_expect(material != null, "socket uses a standard material")
	if material != null:
		_expect(material.albedo_color.is_equal_approx(TEST_BODY_COLOR.darkened(0.18)), "socket contrast derives from the Norn body color")


func test_ear_roots_overlap_head() -> void:
	var head := _mesh("Head")
	var roots := [
		["LeftEar", Vector3(-0.31, 1.90, 0.02), "left"],
		["RightEar", Vector3(0.31, 1.90, 0.02), "right"]
	]
	for root_data: Array in roots:
		var ear := _mesh(str(root_data[0]))
		var root_point: Vector3 = root_data[1]
		var side := str(root_data[2])
		_expect(head != null and _ellipsoid_contains(head, root_point), "%s ear overlap point lies within the head" % side)
		_expect(ear != null and _ellipsoid_contains(ear, root_point), "%s ear root overlaps the head volume" % side)


func test_inner_ear_pads_overlap_outer_ears() -> void:
	var pads := [
		["LeftEarInner", "LeftEar", Vector3(-0.42, 2.19, -0.08), "left"],
		["RightEarInner", "RightEar", Vector3(0.42, 2.19, -0.08), "right"]
	]
	for pad_data: Array in pads:
		var inner := _mesh(str(pad_data[0]))
		var outer := _mesh(str(pad_data[1]))
		var overlap_point: Vector3 = pad_data[2]
		var side := str(pad_data[3])
		_expect(inner != null and _ellipsoid_contains(inner, overlap_point), "%s inner pad contains its inset overlap point" % side)
		_expect(outer != null and _ellipsoid_contains(outer, overlap_point), "%s inner pad overlaps its outer ear" % side)


func test_ear_pairs_are_mirrored() -> void:
	for pair_names: Array in [["LeftEar", "RightEar"], ["LeftEarInner", "RightEarInner"]]:
		var left := _mesh(str(pair_names[0]))
		var right := _mesh(str(pair_names[1]))
		_expect(left != null and right != null, "%s and %s meshes exist" % [pair_names[0], pair_names[1]])
		if left == null or right == null:
			continue
		_expect(absf(left.position.x + right.position.x) <= 0.001, "%s and %s are mirrored across the head" % [pair_names[0], pair_names[1]])
		_expect(absf(left.position.y - right.position.y) <= 0.001 and absf(left.position.z - right.position.z) <= 0.001, "%s and %s share their vertical and depth positions" % [pair_names[0], pair_names[1]])
		_expect(left.scale.is_equal_approx(right.scale), "%s and %s share their mesh scale" % [pair_names[0], pair_names[1]])


func test_ear_tip_height_preserved() -> void:
	for ear_name: String in ["LeftEar", "RightEar"]:
		var ear := _mesh(ear_name)
		_expect(ear != null, "%s mesh exists for tip-height check" % ear_name)
		if ear == null:
			continue
		var sphere := ear.mesh as SphereMesh
		_expect(sphere != null and is_equal_approx(ear.position.y + sphere.radius * ear.scale.y, 2.46), "%s tip stays at the existing y=2.46 height" % ear_name)


func _mesh(node_name: String) -> MeshInstance3D:
	return _actor.find_child(node_name, true, false) as MeshInstance3D


func _head_front_z(head: MeshInstance3D, x: float, y: float) -> float:
	var sphere := head.mesh as SphereMesh
	if sphere == null or sphere.radius <= 0.0:
		return NAN
	var radii := head.scale * sphere.radius
	var normalized_x := (x - head.position.x) / radii.x
	var normalized_y := (y - head.position.y) / radii.y
	var remaining := 1.0 - normalized_x * normalized_x - normalized_y * normalized_y
	if remaining < 0.0:
		return NAN
	return head.position.z - radii.z * sqrt(remaining)


func _sphere_radius_x(mesh: MeshInstance3D) -> float:
	var sphere := mesh.mesh as SphereMesh
	return sphere.radius * mesh.scale.x if sphere != null else 0.0


func _ellipsoid_contains(mesh: MeshInstance3D, point: Vector3) -> bool:
	if mesh == null:
		return false
	var sphere := mesh.mesh as SphereMesh
	if sphere == null or sphere.radius <= 0.0:
		return false
	var radii := mesh.scale * sphere.radius
	if radii.x <= 0.0 or radii.y <= 0.0 or radii.z <= 0.0:
		return false
	var normalized := (point - mesh.position) / radii
	return normalized.length_squared() <= 1.0


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
