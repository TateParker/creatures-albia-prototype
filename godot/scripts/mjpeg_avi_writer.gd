class_name MjpegAviWriter
extends RefCounted

const MAX_AVI_BYTES := 0xF0000000

var _file: FileAccess
var _frame_size := Vector2i.ZERO
var _fps := 0
var _frame_chunks: Array[Dictionary] = []
var _max_frame_size := 0
var _riff_size_position := 0
var _main_max_bytes_per_second_position := 0
var _main_frame_count_position := 0
var _main_suggested_buffer_position := 0
var _stream_frame_count_position := 0
var _stream_suggested_buffer_position := 0
var _movi_list_size_position := 0
var _movi_data_start := 0
var _closed_size := 0


func begin(path: String, size: Vector2i, fps: int) -> Error:
	if _file != null:
		return ERR_ALREADY_IN_USE
	if path.is_empty() or size.x < 1 or size.y < 1 or fps < 1:
		return ERR_INVALID_PARAMETER
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	_file = file
	_file.big_endian = false
	_frame_size = size
	_fps = fps
	_frame_chunks.clear()
	_max_frame_size = 0
	_closed_size = 0

	_write_fourcc("RIFF")
	_riff_size_position = _file.get_position()
	_file.store_32(0)
	_write_fourcc("AVI ")
	_write_header_lists()
	_write_fourcc("LIST")
	_movi_list_size_position = _file.get_position()
	_file.store_32(0)
	_write_fourcc("movi")
	_movi_data_start = _file.get_position()
	return OK


func write_frame(jpeg_bytes: PackedByteArray) -> Error:
	if _file == null:
		return ERR_UNCONFIGURED
	if jpeg_bytes.size() < 4 or jpeg_bytes[0] != 0xFF or jpeg_bytes[1] != 0xD8:
		return ERR_INVALID_DATA
	if _file.get_position() + 8 + jpeg_bytes.size() + (jpeg_bytes.size() % 2) + (_frame_chunks.size() + 1) * 16 + 64 > MAX_AVI_BYTES:
		return ERR_OUT_OF_MEMORY

	var chunk_start := _file.get_position()
	_frame_chunks.append({
		"offset": chunk_start - (_movi_data_start - 4),
		"size": jpeg_bytes.size()
	})
	_max_frame_size = maxi(_max_frame_size, jpeg_bytes.size())
	_write_fourcc("00dc")
	_file.store_32(jpeg_bytes.size())
	_file.store_buffer(jpeg_bytes)
	if jpeg_bytes.size() % 2 != 0:
		_file.store_8(0)
	return OK


func finish() -> Error:
	if _file == null:
		return ERR_UNCONFIGURED
	if _frame_chunks.is_empty():
		_file.close()
		_file = null
		return ERR_INVALID_DATA

	_patch_u32(_movi_list_size_position, _file.get_position() - (_movi_list_size_position + 4))
	_write_fourcc("idx1")
	_file.store_32(_frame_chunks.size() * 16)
	for frame: Dictionary in _frame_chunks:
		_write_fourcc("00dc")
		_file.store_32(0x10)
		_file.store_32(int(frame["offset"]))
		_file.store_32(int(frame["size"]))
	var final_size := _file.get_position()
	_patch_u32(_riff_size_position, final_size - 8)
	_patch_u32(_main_max_bytes_per_second_position, (_max_frame_size + 8) * _fps)
	_patch_u32(_main_frame_count_position, _frame_chunks.size())
	_patch_u32(_main_suggested_buffer_position, _max_frame_size)
	_patch_u32(_stream_frame_count_position, _frame_chunks.size())
	_patch_u32(_stream_suggested_buffer_position, _max_frame_size)
	_file.close()
	_file = null
	_closed_size = final_size
	return OK


func bytes_written() -> int:
	if _file != null:
		return int(_file.get_position())
	return _closed_size


func frame_count() -> int:
	return _frame_chunks.size()


func _write_header_lists() -> void:
	_write_fourcc("LIST")
	var hdrl_size_position := _file.get_position()
	_file.store_32(0)
	_write_fourcc("hdrl")
	_write_main_header()

	_write_fourcc("LIST")
	var strl_size_position := _file.get_position()
	_file.store_32(0)
	_write_fourcc("strl")
	_write_stream_header()
	_write_bitmap_header()
	_patch_u32(strl_size_position, _file.get_position() - (strl_size_position + 4))
	_patch_u32(hdrl_size_position, _file.get_position() - (hdrl_size_position + 4))


func _write_main_header() -> void:
	_write_fourcc("avih")
	_file.store_32(56)
	var data_start := _file.get_position()
	_file.store_32(1000000 / _fps)
	_main_max_bytes_per_second_position = _file.get_position()
	_file.store_32(0)
	_file.store_32(0)
	_file.store_32(0x10)
	_main_frame_count_position = _file.get_position()
	_file.store_32(0)
	_file.store_32(0)
	_file.store_32(1)
	_main_suggested_buffer_position = _file.get_position()
	_file.store_32(0)
	_file.store_32(_frame_size.x)
	_file.store_32(_frame_size.y)
	for reserved_index in range(4):
		_file.store_32(0)
	assert(_file.get_position() - data_start == 56)


func _write_stream_header() -> void:
	_write_fourcc("strh")
	_file.store_32(56)
	var data_start := _file.get_position()
	_write_fourcc("vids")
	_write_fourcc("MJPG")
	_file.store_32(0)
	_file.store_16(0)
	_file.store_16(0)
	_file.store_32(0)
	_file.store_32(1)
	_file.store_32(_fps)
	_file.store_32(0)
	_stream_frame_count_position = _file.get_position()
	_file.store_32(0)
	_stream_suggested_buffer_position = _file.get_position()
	_file.store_32(0)
	_file.store_32(0)
	_file.store_32(0)
	_file.store_16(0)
	_file.store_16(0)
	_file.store_16(_frame_size.x)
	_file.store_16(_frame_size.y)
	assert(_file.get_position() - data_start == 56)


func _write_bitmap_header() -> void:
	_write_fourcc("strf")
	_file.store_32(40)
	_file.store_32(40)
	_file.store_32(_frame_size.x)
	_file.store_32(_frame_size.y)
	_file.store_16(1)
	_file.store_16(24)
	_write_fourcc("MJPG")
	_file.store_32(_frame_size.x * _frame_size.y * 3)
	_file.store_32(0)
	_file.store_32(0)
	_file.store_32(0)
	_file.store_32(0)


func _write_fourcc(value: String) -> void:
	_file.store_buffer(value.to_ascii_buffer())


func _patch_u32(position: int, value: int) -> void:
	var end_position := _file.get_position()
	_file.seek(position)
	_file.store_32(value)
	_file.seek(end_position)
