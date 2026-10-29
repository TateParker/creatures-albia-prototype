extends SceneTree


func _initialize() -> void:
	call_deferred("_inspect_recording")


func _inspect_recording() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.is_empty():
		_fail("Pass an AVI path after --. Optional second argument: a folder for extracted PNG frames.")
		return
	var video_path := str(arguments[0])
	if video_path.begins_with("user://"):
		video_path = ProjectSettings.globalize_path(video_path)
	var output_directory := str(arguments[1]) if arguments.size() > 1 else OS.get_temp_dir().path_join("albia-recording-frames")
	var video := FileAccess.open(video_path, FileAccess.READ)
	if video == null:
		_fail("Could not open AVI: %s" % video_path)
		return
	var bytes := video.get_buffer(video.get_length())
	video.close()
	if _ascii(bytes, 0, 4) != "RIFF" or _ascii(bytes, 8, 4) != "AVI " or _u32(bytes, 4) != bytes.size() - 8:
		_fail("The file does not have a valid finalized RIFF/AVI header.")
		return
	var expected_frames := _u32(bytes, 48)
	var expected_stream_frames := _u32(bytes, 140)
	var video_size := Vector2i(_u32(bytes, 64), _u32(bytes, 68))
	if expected_frames < 1 or expected_frames != expected_stream_frames or video_size != Vector2i(1280, 720):
		_fail("AVI headers disagree or do not describe a 1280x720 stream (%d/%d frames, %s)." % [expected_frames, expected_stream_frames, str(video_size)])
		return
	var movi_marker := _find_ascii(bytes, "movi")
	var index_marker := _find_ascii(bytes, "idx1")
	if movi_marker < 0 or index_marker < 0 or index_marker <= movi_marker:
		_fail("The AVI is missing its movie data or final index.")
		return
	if _u32(bytes, index_marker + 4) != expected_frames * 16:
		_fail("The AVI index size does not match its declared frame count.")
		return
	var directory_error := DirAccess.make_dir_recursive_absolute(output_directory)
	if directory_error != OK and not DirAccess.dir_exists_absolute(output_directory):
		_fail("Could not create the extracted-frame folder (error %d)." % directory_error)
		return
	var sample_percentages: Array[int] = [0, 20, 40, 50, 60, 70, 80, 88, 92, 94, 95, 96, 97, 98, 99, 100]
	var sample_frames: Dictionary = {}
	for percentage: int in sample_percentages:
		var frame_index := roundi(float(expected_frames - 1) * float(percentage) / 100.0)
		sample_frames[frame_index] = true
	var frame_offset := movi_marker + 4
	var decoded_frames := 0
	while frame_offset < index_marker:
		if _ascii(bytes, frame_offset, 4) != "00dc":
			_fail("Unexpected AVI frame chunk at byte %d." % frame_offset)
			return
		var jpeg_size := _u32(bytes, frame_offset + 4)
		if jpeg_size < 4 or frame_offset + 8 + jpeg_size > index_marker:
			_fail("AVI frame %d has an invalid JPEG chunk size." % decoded_frames)
			return
		var index_entry := index_marker + 8 + decoded_frames * 16
		if _ascii(bytes, index_entry, 4) != "00dc" or _u32(bytes, index_entry + 8) != frame_offset - movi_marker or _u32(bytes, index_entry + 12) != jpeg_size:
			_fail("AVI index entry %d does not point to its frame chunk." % decoded_frames)
			return
		var image := Image.new()
		var jpeg := bytes.slice(frame_offset + 8, frame_offset + 8 + jpeg_size)
		if image.load_jpg_from_buffer(jpeg) != OK or image.get_size() != video_size:
			_fail("AVI frame %d did not decode at the declared 1280x720 size." % decoded_frames)
			return
		if sample_frames.has(decoded_frames):
			var sample_path := output_directory.path_join("frame-%04d-of-%04d.png" % [decoded_frames, expected_frames - 1])
			var save_error := image.save_png(sample_path)
			if save_error != OK:
				_fail("Could not save inspected frame %d (error %d)." % [decoded_frames, save_error])
				return
		decoded_frames += 1
		frame_offset += 8 + jpeg_size + (jpeg_size % 2)
	if decoded_frames != expected_frames or frame_offset != index_marker:
		_fail("AVI contained %d decoded frames and ended at byte %d; expected %d frames ending at index %d." % [decoded_frames, frame_offset, expected_frames, index_marker])
		return
	print("AVI_INSPECTION_OK frames=%d decoded=%d dimensions=%dx%d sampled=%d output=%s" % [expected_frames, decoded_frames, video_size.x, video_size.y, sample_frames.size(), output_directory])
	quit()


func _fail(message: String) -> void:
	push_error("AVI_INSPECTION_FAILED: " + message)
	quit(1)


func _ascii(bytes: PackedByteArray, offset: int, length: int) -> String:
	if offset < 0 or offset + length > bytes.size():
		return ""
	return bytes.slice(offset, offset + length).get_string_from_ascii()


func _u32(bytes: PackedByteArray, offset: int) -> int:
	if offset < 0 or offset + 4 > bytes.size():
		return -1
	return int(bytes.decode_u32(offset))


func _find_ascii(bytes: PackedByteArray, value: String) -> int:
	var marker := value.to_ascii_buffer()
	for offset in range(bytes.size() - marker.size() + 1):
		var matches := true
		for marker_index in range(marker.size()):
			if bytes[offset + marker_index] != marker[marker_index]:
				matches = false
				break
		if matches:
			return offset
	return -1
