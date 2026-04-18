
var _ds = (_data_size - _data_offset); if (sign(_ds)) {
	var _cs = (min(_ds, _chunk_size));
	var _id_b = (buffer_create(_cs, buffer_fixed, 1));
	buffer_load_partial(_id_b, _path, _data_offset, _cs, 0);
	_data_offset += _cs;
	audio_queue_sound(_, _id_b, 0, _cs);
};
