extends SceneTree

const WriterScriptPath := "res://scripts/mjpeg_avi_writer.gd"


func _initialize() -> void:
	call_deferred("_verify_writer")


func _verify_writer() -> void:
	var writer_script: Script = load(WriterScriptPath)
	if writer_script == null:
		_fail("MJPEG AVI writer is not implemented yet.")
		return
	var output_path := OS.get_user_data_dir().path_join("writer-smoke-test.avi")
	var writer: Object = writer_script.new()
	var begin_error: int = writer.call("begin", output_path, Vector2i(64, 64), 15)
	if begin_error != OK:
		_fail("AVI writer failed to open its output (error %d)." % begin_error)
		return

	var first_image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	first_image.fill(Color(0.8, 0.2, 0.1))
	var second_image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	second_image.fill(Color(0.1, 0.6, 0.8))
	for image: Image in [first_image, second_image]:
		var frame_error: int = writer.call("write_frame", image.save_jpg_to_buffer(0.75))
		if frame_error != OK:
			_fail("AVI writer failed to write a JPEG frame (error %d)." % frame_error)
			return
	var finish_error: int = writer.call("finish")
	if finish_error != OK:
		_fail("AVI writer failed to finalize its index (error %d)." % finish_error)
		return

	var video := FileAccess.open(output_path, FileAccess.READ)
	if video == null:
		_fail("AVI writer did not create an output file.")
		return
	var bytes := video.get_buffer(video.get_length())
	video.close()
	if _ascii(bytes, 0, 4) != "RIFF" or _ascii(bytes, 8, 4) != "AVI ":
		_fail("Output is missing the RIFF/AVI signature.")
		return
	if _u32(bytes, 4) != bytes.size() - 8:
		_fail("RIFF file size was not patched to the final file length.")
		return
	if _u32(bytes, 48) != 2 or _u32(bytes, 140) != 2:
		_fail("AVI headers did not record both frames.")
		return
	if _u32(bytes, 64) != 64 or _u32(bytes, 68) != 64:
		_fail("AVI dimensions do not match the source frames.")
		return
	if _u32(bytes, 152) != 0 or _u32(bytes, 192) != 64 * 64 * 3:
		_fail("AVI stream sample size or MJPEG bitmap size is invalid.")
		return
	if _u32(bytes, 36) < 15 * 8:
		_fail("AVI does not advertise a usable maximum video data rate.")
		return

	var movi_marker := _find_ascii(bytes, "movi")
	var index_marker := _find_ascii(bytes, "idx1")
	if movi_marker < 0 or index_marker < 0:
		_fail("AVI is missing its movie data or final index.")
		return
	var frame_offset := movi_marker + 4
	var decoded_frames := 0
	while frame_offset < index_marker:
		if _ascii(bytes, frame_offset, 4) != "00dc":
			_fail("Unexpected AVI frame chunk at byte %d." % frame_offset)
			return
		var jpeg_size := _u32(bytes, frame_offset + 4)
		if jpeg_size == 0 or frame_offset + 8 + jpeg_size > index_marker:
			_fail("AVI frame chunk has an invalid size.")
			return
		if decoded_frames == 0:
			var jpeg := bytes.slice(frame_offset + 8, frame_offset + 8 + jpeg_size)
			var decoded_image := Image.new()
			if decoded_image.load_jpg_from_buffer(jpeg) != OK:
				_fail("The first AVI frame does not contain a decodable JPEG.")
				return
		var index_entry := index_marker + 8 + decoded_frames * 16
		if _ascii(bytes, index_entry, 4) != "00dc":
			_fail("AVI frame index entry %d has an invalid chunk id." % decoded_frames)
			return
		if _u32(bytes, index_entry + 8) != frame_offset - movi_marker or _u32(bytes, index_entry + 12) != jpeg_size:
			_fail("AVI frame index entry %d has an invalid offset or size." % decoded_frames)
			return
		decoded_frames += 1
		frame_offset += 8 + jpeg_size + (jpeg_size % 2)

	if decoded_frames != 2 or _u32(bytes, index_marker + 4) != 32:
		_fail("AVI should contain two indexed frames; found %d." % decoded_frames)
		return
	DirAccess.remove_absolute(output_path)
	print("AVI_WRITER_OK frames=%d dimensions=64x64" % decoded_frames)
	quit()


func _fail(message: String) -> void:
	push_error("AVI_WRITER_FAILED: " + message)
	quit(1)


func _ascii(bytes: PackedByteArray, offset: int, length: int) -> String:
	return bytes.slice(offset, offset + length).get_string_from_ascii()


func _u32(bytes: PackedByteArray, offset: int) -> int:
	return int(bytes.decode_u32(offset))


func _find_ascii(bytes: PackedByteArray, text: String) -> int:
	var marker := text.to_ascii_buffer()
	for offset in range(bytes.size() - marker.size() + 1):
		var matches := true
		for character_index in range(marker.size()):
			if bytes[offset + character_index] != marker[character_index]:
				matches = false
				break
		if matches:
			return offset
	return -1
