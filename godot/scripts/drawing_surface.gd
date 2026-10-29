class_name DrawingSurface
extends RefCounted

const STATE_VERSION := 1
const SURFACE_SIZE := 256
const MAX_STROKES := 256
const MAX_POINTS_PER_STROKE := 128
const MAX_CURSORS := 4
const SAMPLE_WINDOW_UV := 0.5
const BACKGROUND_COLOR := Color(0.92, 0.87, 0.73, 1.0)
const INK_COLOR := Color(0.12, 0.10, 0.075, 1.0)

var image: Image
var texture: ImageTexture
var _background_luma := 0.0
var _strokes: Array[Dictionary] = []
var _active_by_actor: Dictionary = {}
var _last_uv_by_actor: Dictionary = {}
var _cursor_order: Array[String] = []
var _completed_by_actor: Dictionary = {}


func _init() -> void:
	image = _create_blank_image()
	_background_luma = _luma(image.get_pixel(0, 0))
	texture = ImageTexture.create_from_image(image)


func append_point(actor_id: String, uv: Vector2, pressure: float, contact: bool) -> bool:
	if not _valid_actor_id(actor_id) or not _valid_uv(uv) or not is_finite(pressure) or pressure < 0.0 or pressure > 1.0:
		return false
	var point := {
		"x": clampi(roundi(uv.x * float(SURFACE_SIZE - 1)), 0, SURFACE_SIZE - 1),
		"y": clampi(roundi(uv.y * float(SURFACE_SIZE - 1)), 0, SURFACE_SIZE - 1),
		"pressure": clampi(roundi(pressure * 255.0), 0, 255)
	}
	if not contact:
		_set_last_uv(actor_id, _point_to_uv(point))
		_close_stroke(actor_id)
		return true
	var stroke_index := int(_active_by_actor.get(actor_id, -1))
	if stroke_index >= 0 and stroke_index < _strokes.size():
		var current_stroke: Dictionary = _strokes[stroke_index]
		var current_points: Array = current_stroke["points"]
		if current_points.size() >= MAX_POINTS_PER_STROKE:
			_close_stroke(actor_id)
			stroke_index = -1
	if stroke_index < 0:
		stroke_index = _begin_stroke(actor_id, point)
	else:
		var stroke: Dictionary = _strokes[stroke_index]
		var points: Array = stroke["points"]
		var previous: Dictionary = points[points.size() - 1]
		points.append(point)
		stroke["points"] = points
		_strokes[stroke_index] = stroke
		_draw_segment(previous, point)
	_set_last_uv(actor_id, _point_to_uv(point))
	texture.update(image)
	return true


func sample_mark_grid(origin_uv: Vector2, side: int = 16) -> PackedFloat32Array:
	if not _valid_uv(origin_uv) or side < 1 or side > 64:
		return PackedFloat32Array()
	var result := PackedFloat32Array()
	result.resize(side * side)
	result.fill(0.0)
	var cell_extent := SAMPLE_WINDOW_UV / float(side)
	var window_minimum := origin_uv - Vector2.ONE * (SAMPLE_WINDOW_UV * 0.5)
	for y: int in range(side):
		for x: int in range(side):
			var sample := 0.0
			var cell_minimum := window_minimum + Vector2(x, y) * cell_extent
			var cell_maximum := cell_minimum + Vector2.ONE * cell_extent
			if cell_maximum.x >= 0.0 and cell_minimum.x <= 1.0 and cell_maximum.y >= 0.0 and cell_minimum.y <= 1.0:
				var minimum_pixel := Vector2i(
					clampi(floori(cell_minimum.x * float(SURFACE_SIZE - 1)), 0, SURFACE_SIZE - 1),
					clampi(floori(cell_minimum.y * float(SURFACE_SIZE - 1)), 0, SURFACE_SIZE - 1)
				)
				var maximum_pixel := Vector2i(
					clampi(ceili(cell_maximum.x * float(SURFACE_SIZE - 1)), 0, SURFACE_SIZE - 1),
					clampi(ceili(cell_maximum.y * float(SURFACE_SIZE - 1)), 0, SURFACE_SIZE - 1)
				)
				for pixel_y: int in range(minimum_pixel.y, maximum_pixel.y + 1):
					for pixel_x: int in range(minimum_pixel.x, maximum_pixel.x + 1):
						var ink := clampf((_background_luma - _luma(image.get_pixel(pixel_x, pixel_y))) / _background_luma, 0.0, 1.0)
						sample = maxf(sample, ink)
			result[y * side + x] = sample
	return result


func get_last_uv(actor_id: String) -> Vector2:
	var last: Variant = _last_uv_by_actor.get(actor_id, Vector2(0.5, 0.5))
	return last if last is Vector2 else Vector2(0.5, 0.5)


func get_stroke_count() -> int:
	return _strokes.size()


func pop_completed_stroke(actor_id: String) -> Dictionary:
	var value: Variant = _completed_by_actor.get(actor_id, null)
	if not (value is Dictionary):
		return {}
	_completed_by_actor.erase(actor_id)
	return (value as Dictionary).duplicate(true)


func serialize_state() -> Dictionary:
	var cursors: Array[Dictionary] = []
	for actor_id: String in _cursor_order:
		var uv: Vector2 = _last_uv_by_actor[actor_id]
		cursors.append({
			"actorId": actor_id,
			"x": clampi(roundi(uv.x * float(SURFACE_SIZE - 1)), 0, SURFACE_SIZE - 1),
			"y": clampi(roundi(uv.y * float(SURFACE_SIZE - 1)), 0, SURFACE_SIZE - 1)
		})
	return {"version": STATE_VERSION, "strokes": _strokes.duplicate(true), "cursors": cursors}


func restore_state(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var record: Dictionary = value
	if not _is_integer_number(record.get("version", null)) or int(record["version"]) != STATE_VERSION:
		return false
	var raw_strokes: Variant = record.get("strokes", null)
	if not (raw_strokes is Array) or raw_strokes.size() > MAX_STROKES:
		return false
	var raw_cursors: Variant = record.get("cursors", [])
	if not (raw_cursors is Array) or raw_cursors.size() > MAX_CURSORS:
		return false
	var candidate_strokes: Array[Dictionary] = []
	var candidate_active: Dictionary = {}
	var stroke_last_uvs: Dictionary = {}
	var stroke_cursor_order: Array[String] = []
	for raw_stroke: Variant in raw_strokes:
		if not (raw_stroke is Dictionary):
			return false
		var stroke: Dictionary = raw_stroke
		var actor_id: Variant = stroke.get("actorId", null)
		var active: Variant = stroke.get("active", null)
		var raw_points: Variant = stroke.get("points", null)
		if not (actor_id is String) or not _valid_actor_id(actor_id) or not (active is bool):
			return false
		if not (raw_points is Array) or raw_points.is_empty() or raw_points.size() > MAX_POINTS_PER_STROKE:
			return false
		if bool(active) and candidate_active.has(actor_id):
			return false
		var points: Array[Dictionary] = []
		for raw_point: Variant in raw_points:
			if not (raw_point is Dictionary):
				return false
			var point: Dictionary = raw_point
			if not _is_integer_number(point.get("x", null)) or not _is_integer_number(point.get("y", null)) or not _is_integer_number(point.get("pressure", null)):
				return false
			if int(point["x"]) < 0 or int(point["x"]) >= SURFACE_SIZE or int(point["y"]) < 0 or int(point["y"]) >= SURFACE_SIZE or int(point["pressure"]) < 0 or int(point["pressure"]) > 255:
				return false
			points.append({"x": int(point["x"]), "y": int(point["y"]), "pressure": int(point["pressure"])})
		var clean_stroke := {"actorId": actor_id, "active": bool(active), "points": points}
		candidate_strokes.append(clean_stroke)
		if bool(active):
			candidate_active[actor_id] = candidate_strokes.size() - 1
		var last_point: Dictionary = points[points.size() - 1]
		stroke_cursor_order.erase(str(actor_id))
		stroke_cursor_order.append(str(actor_id))
		stroke_last_uvs[actor_id] = _point_to_uv(last_point)
	var candidate_last: Dictionary = {}
	var candidate_cursor_order: Array[String] = []
	if raw_cursors.is_empty():
		var first_cursor := maxi(0, stroke_cursor_order.size() - MAX_CURSORS)
		for index: int in range(first_cursor, stroke_cursor_order.size()):
			var actor_id := stroke_cursor_order[index]
			candidate_cursor_order.append(actor_id)
			candidate_last[actor_id] = stroke_last_uvs[actor_id]
	var seen_cursors: Dictionary = {}
	for raw_cursor: Variant in raw_cursors:
		if not (raw_cursor is Dictionary):
			return false
		var cursor: Dictionary = raw_cursor
		var actor_id: Variant = cursor.get("actorId", null)
		if not (actor_id is String) or not _valid_actor_id(actor_id) or seen_cursors.has(actor_id):
			return false
		if not _is_integer_number(cursor.get("x", null)) or not _is_integer_number(cursor.get("y", null)):
			return false
		if int(cursor["x"]) < 0 or int(cursor["x"]) >= SURFACE_SIZE or int(cursor["y"]) < 0 or int(cursor["y"]) >= SURFACE_SIZE:
			return false
		seen_cursors[actor_id] = true
		candidate_cursor_order.append(str(actor_id))
		candidate_last[actor_id] = Vector2(float(cursor["x"]) / float(SURFACE_SIZE - 1), float(cursor["y"]) / float(SURFACE_SIZE - 1))
	var candidate_image := _render_strokes(candidate_strokes)
	_strokes = candidate_strokes
	_active_by_actor = candidate_active
	_last_uv_by_actor = candidate_last
	_cursor_order = candidate_cursor_order
	_completed_by_actor.clear()
	image = candidate_image
	texture.update(image)
	return true


func _begin_stroke(actor_id: String, point: Dictionary) -> int:
	if _strokes.size() >= MAX_STROKES:
		_strokes.pop_front()
		_rebuild_active_indices()
		_rebuild_image()
	var stroke := {"actorId": actor_id, "active": true, "points": [point]}
	_strokes.append(stroke)
	var index := _strokes.size() - 1
	_active_by_actor[actor_id] = index
	_draw_dot(point)
	return index


func _set_last_uv(actor_id: String, uv: Vector2) -> void:
	_cursor_order.erase(actor_id)
	if not _last_uv_by_actor.has(actor_id) and _cursor_order.size() >= MAX_CURSORS:
		var oldest_actor_id: String = _cursor_order.pop_front()
		_last_uv_by_actor.erase(oldest_actor_id)
	_cursor_order.append(actor_id)
	_last_uv_by_actor[actor_id] = uv


func _close_stroke(actor_id: String) -> void:
	var stroke_index := int(_active_by_actor.get(actor_id, -1))
	if stroke_index < 0 or stroke_index >= _strokes.size():
		return
	var stroke: Dictionary = _strokes[stroke_index]
	stroke["active"] = false
	_strokes[stroke_index] = stroke
	_active_by_actor.erase(actor_id)
	_completed_by_actor[actor_id] = stroke.duplicate(true)


func _rebuild_active_indices() -> void:
	_active_by_actor.clear()
	for index: int in range(_strokes.size()):
		var stroke: Dictionary = _strokes[index]
		if bool(stroke.get("active", false)):
			_active_by_actor[str(stroke["actorId"])] = index


func _draw_segment(from_point: Dictionary, to_point: Dictionary) -> void:
	_paint_segment(image, from_point, to_point)


func _draw_dot(point: Dictionary) -> void:
	_paint_dot(image, point)


func _rebuild_image() -> void:
	image = _render_strokes(_strokes)
	texture.update(image)


func _render_strokes(strokes: Array[Dictionary]) -> Image:
	var rendered := _create_blank_image()
	for stroke: Dictionary in strokes:
		var points: Array = stroke["points"]
		if points.size() == 1:
			_paint_dot(rendered, points[0])
		else:
			for point_index: int in range(1, points.size()):
				var previous: Dictionary = points[point_index - 1]
				var current: Dictionary = points[point_index]
				_paint_segment(rendered, previous, current)
	return rendered


func _paint_segment(target: Image, from_point: Dictionary, to_point: Dictionary) -> void:
	var from_pixel := Vector2i(int(from_point["x"]), int(from_point["y"]))
	var to_pixel := Vector2i(int(to_point["x"]), int(to_point["y"]))
	var pressure := float(to_point["pressure"]) / 255.0
	var radius := maxi(1, roundi(0.75 + pressure * 1.25))
	var span := to_pixel - from_pixel
	var steps := maxi(absi(span.x), absi(span.y))
	if steps == 0:
		_paint_brush(target, to_pixel, radius)
		return
	for step: int in range(steps + 1):
		var amount := float(step) / float(steps)
		var pixel := Vector2i(roundi(lerpf(float(from_pixel.x), float(to_pixel.x), amount)), roundi(lerpf(float(from_pixel.y), float(to_pixel.y), amount)))
		_paint_brush(target, pixel, radius)


func _paint_dot(target: Image, point: Dictionary) -> void:
	var pixel := Vector2i(int(point["x"]), int(point["y"]))
	var pressure := float(point["pressure"]) / 255.0
	_paint_brush(target, pixel, maxi(1, roundi(0.75 + pressure * 1.25)))


func _paint_brush(target: Image, center: Vector2i, radius: int) -> void:
	var radius_squared := radius * radius
	for y: int in range(center.y - radius, center.y + radius + 1):
		for x: int in range(center.x - radius, center.x + radius + 1):
			if x < 0 or x >= SURFACE_SIZE or y < 0 or y >= SURFACE_SIZE:
				continue
			var offset := Vector2i(x, y) - center
			if offset.length_squared() <= radius_squared:
				target.set_pixel(x, y, INK_COLOR)


func _valid_uv(uv: Vector2) -> bool:
	return is_finite(uv.x) and is_finite(uv.y) and uv.x >= 0.0 and uv.x <= 1.0 and uv.y >= 0.0 and uv.y <= 1.0


func _valid_actor_id(actor_id: String) -> bool:
	if actor_id.is_empty() or actor_id.length() > 40:
		return false
	for index: int in range(actor_id.length()):
		var code := actor_id.unicode_at(index)
		var is_letter := (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		var is_digit := code >= 48 and code <= 57
		if not (is_letter or is_digit or code == 45 or code == 95):
			return false
	return true


func _is_integer_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(float(value)) and is_equal_approx(float(value), roundf(float(value)))


func _point_to_uv(point: Dictionary) -> Vector2:
	return Vector2(float(point["x"]) / float(SURFACE_SIZE - 1), float(point["y"]) / float(SURFACE_SIZE - 1))


func _create_blank_image() -> Image:
	var blank := Image.create(SURFACE_SIZE, SURFACE_SIZE, false, Image.FORMAT_RGBA8)
	blank.fill(BACKGROUND_COLOR)
	return blank


func _luma(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
