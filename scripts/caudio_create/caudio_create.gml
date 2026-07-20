/* began */
enum CAUDIO_AUDIO_TYPE {
	IDK,
	WAV,
	FLAC,
	OGG_VORBIS
};

function caudio_create() {
	static helper = {
		findHeader: function(_path) {
			var _file = file_bin_open(_path, 0);
			if (_file < 0) then return(CAUDIO_AUDIO_TYPE.IDK);
			var _file_size = file_bin_size(_file);
			file_bin_close(_file);
			if (_file_size < 12) then return(CAUDIO_AUDIO_TYPE.IDK);
			var _probe_size = min(_file_size, 290);
			var _id_b = (buffer_create(_probe_size, buffer_fixed, 1));
			buffer_load_partial(_id_b, _path, 0, _probe_size, 0);
			buffer_seek(_id_b, buffer_seek_start, 0);
			var _sig32 = (buffer_read(_id_b, buffer_u32));
			
			if (_sig32 == 0x46464952) {
				var _wave_id = (buffer_peek(_id_b, 8, buffer_u32));
				buffer_delete(_id_b);
				return((_wave_id == 0x45564157) ? CAUDIO_AUDIO_TYPE.WAV : CAUDIO_AUDIO_TYPE.IDK);
			} elif (_sig32 == 0x43614C66) {
				buffer_delete(_id_b);
				return(CAUDIO_AUDIO_TYPE.FLAC);
			} elif ((_sig32 == 0x5367674F) && (_probe_size >= 27)) {
				var _segments = buffer_peek(_id_b, 26, buffer_u8);
				var _packet = 27 + _segments;
				if ((_packet + 7 <= _probe_size)
					&& (buffer_peek(_id_b, _packet, buffer_u8) == 1)
					&& (buffer_peek(_id_b, _packet + 1, buffer_u8) == 0x76)
					&& (buffer_peek(_id_b, _packet + 2, buffer_u8) == 0x6F)
					&& (buffer_peek(_id_b, _packet + 3, buffer_u8) == 0x72)
					&& (buffer_peek(_id_b, _packet + 4, buffer_u8) == 0x62)
					&& (buffer_peek(_id_b, _packet + 5, buffer_u8) == 0x69)
					&& (buffer_peek(_id_b, _packet + 6, buffer_u8) == 0x73)) {
					buffer_delete(_id_b);
					return(CAUDIO_AUDIO_TYPE.OGG_VORBIS);
				};
			};
			buffer_delete(_id_b);
			return(CAUDIO_AUDIO_TYPE.IDK);
		},
	};
	return(helper);
};

function caudio_create_sound(_path) {
	static helper = (caudio_create());
	var _r = undefined;
	switch (helper.findHeader(_path)) {
		case(CAUDIO_AUDIO_TYPE.WAV):
			_r = (caudio_create_sound_wav(_path));
			break;
		case(CAUDIO_AUDIO_TYPE.FLAC):
			_r = (caudio_create_sound_flac(_path));
			break;
		case(CAUDIO_AUDIO_TYPE.OGG_VORBIS):
			show_debug_message("[CAudio] [OGG] E: Buffer sounds are unsupported; use caudio_create_stream.");
			_r = -1;
			break;
		default:
			show_debug_message("[CAudio] E: Unknown audio format.");
			_r = -1;
			break;
	};
	return(_r);
};

function caudio_create_stream(_path) {
	static helper = (caudio_create());
	var _r = undefined;
	switch (helper.findHeader(_path)) {
		case(CAUDIO_AUDIO_TYPE.WAV):
			_r = (caudio_create_stream_wav(_path));
			break;
		case(CAUDIO_AUDIO_TYPE.FLAC):
			_r = (caudio_create_stream_flac(_path));
			break;
		case(CAUDIO_AUDIO_TYPE.OGG_VORBIS):
			var _audio_id = audio_create_stream(_path);
			if (_audio_id < 0) {
				show_debug_message("[CAudio] [OGG] E: audio_create_stream failed.");
				_r = -1;
			} else {
				var _playable = audio_sound_is_playable(_audio_id);
				var _duration = _playable ? audio_sound_length(_audio_id) : -1;
				_r = {
					audioID: _audio_id,
					header: { duration: max(0, _duration) },
					path: _path,
					playable: _playable,
					loop: false,
					playId: -1,
					done: false,
					kind: "ogg",
					mode: "stream",
				};
			};
			break;
		default:
			show_debug_message("[CAudio] E: Unknown audio format.");
			_r = -1;
			break;
	};
	return(_r);
};

function caudio_retired_queue_registry() {
	static _registry = { queues: [] };
	return(_registry);
};

function caudio_retired_queue_register(_queue_id, _buffers) {
	if ((_queue_id < 0) || !is_array(_buffers) || (array_length(_buffers) == 0)) then return(0);
	var _registry = caudio_retired_queue_registry();
	array_push(_registry.queues, { queueId: _queue_id, buffers: _buffers });
	return(array_length(_buffers));
};

function caudio_retired_queue_on_async(_async_map) {
	var _bid = (_async_map[? "buffer_id"]);
	var _qid = (_async_map[? "queue_id"]);
	var _registry = caudio_retired_queue_registry();
	var _queue_index = 0;
	while (_queue_index < array_length(_registry.queues)) {
		var _queue = _registry.queues[_queue_index];
		if ((_queue.queueId) == _qid) {
			var _buffer_index = array_get_index(_queue.buffers, _bid);
			if (_buffer_index >= 0) {
				if (buffer_exists(_bid)) then buffer_delete(_bid);
				array_delete(_queue.buffers, _buffer_index, 1);
				if (array_length(_queue.buffers) == 0) then array_delete(_registry.queues, _queue_index, 1);
				return(true);
			};
		};
		_queue_index += 1;
	};
	return(false);
};

function caudio_retired_queue_pending() {
	var _queues = caudio_retired_queue_registry().queues;
	var _pending = 0;
	var _index = 0;
	while (_index < array_length(_queues)) {
		_pending += array_length(_queues[_index].buffers);
		_index += 1;
	};
	return(_pending);
};

function caudio_stream_is_playable(_stream) {
	if (!is_struct(_stream)) then return(false);
	if ((variable_struct_exists(_stream, "done")) && _stream.done) then return(false);
	if ((variable_struct_exists(_stream, "kind")) && ((_stream.kind) == "ogg")) {
		if ((_stream.audioID) < 0) {
			_stream.playable = false;
			return(false);
		};
		_stream.playable = audio_sound_is_playable(_stream.audioID);
		if (_stream.playable && ((_stream.header.duration) <= 0)) {
			var _duration = audio_sound_length(_stream.audioID);
			if (_duration >= 0) then _stream.header.duration = _duration;
		};
		return(_stream.playable);
	};
	return(true);
};

function caudio_stream_fill(_stream) {
	if (!is_struct(_stream)) then return(false);
	if ((variable_struct_exists(_stream, "kind")) && ((_stream.kind) == "ogg")) then return(false);
	if ((variable_struct_exists(_stream, "kind")) && ((_stream.kind) == "flac")) {
		return(caudio_stream_fill_flac(_stream));
	};
	return(caudio_stream_fill_wav(_stream));
};

function caudio_stream_prime(_stream, _min_queued = 3) {
	if (!is_struct(_stream)) then return(0);
	if ((variable_struct_exists(_stream, "kind")) && ((_stream.kind) == "ogg")) then return(0);
	if ((variable_struct_exists(_stream, "kind")) && ((_stream.kind) == "flac")) {
		return(caudio_stream_prime_flac(_stream, _min_queued));
	};
	return(caudio_stream_prime_wav(_stream, _min_queued));
};

function caudio_stream_on_async(_stream, _async_map, _min_queued = 3) {
	if (is_struct(_stream) && (!(variable_struct_exists(_stream, "kind")) || ((_stream.kind) != "ogg"))) {
		if ((variable_struct_exists(_stream, "kind")) && ((_stream.kind) == "flac")) {
			caudio_stream_on_async_flac(_stream, _async_map, _min_queued);
		} else {
			caudio_stream_on_async_wav(_stream, _async_map, _min_queued);
		};
	};
	caudio_retired_queue_on_async(_async_map);
};

function caudio_stream_free(_stream) {
	if (!is_struct(_stream)) then return;
	if ((variable_struct_exists(_stream, "kind")) && ((_stream.kind) == "ogg")) {
		if (audio_exists(_stream.playId)) then audio_stop_sound(_stream.playId);
		if (variable_struct_exists(_stream, "audioID") && (_stream.audioID >= 0)) {
			audio_destroy_stream(_stream.audioID);
			_stream.audioID = -1;
		};
		_stream.playId = -1;
		_stream.playable = false;
		_stream.done = true;
		return;
	};
	if ((variable_struct_exists(_stream, "kind")) && ((_stream.kind) == "flac")) {
		caudio_stream_free_flac(_stream);
		return;
	};
	caudio_stream_free_wav(_stream);
};

function caudio_free(_handle) {
	if (!is_struct(_handle)) then return;
	if ((variable_struct_exists(_handle, "mode")) && ((_handle.mode) == "stream")) {
		caudio_stream_free(_handle);
		return;
	};
	if ((variable_struct_exists(_handle, "kind")) && ((_handle.kind) == "flac")) {
		caudio_free_sound_flac(_handle);
		return;
	};
	caudio_free_sound_wav(_handle);
};

function caudio_play(_handle, _priority = 0, _loop = false) {
	if (!is_struct(_handle)) then return(-1);
	if ((variable_struct_exists(_handle, "mode")) && ((_handle.mode) == "stream")) {
			if ((variable_struct_exists(_handle, "kind")) && ((_handle.kind) == "ogg")) {
				if (!caudio_stream_is_playable(_handle)) then return(-1);
				_handle.loop = bool(_loop);
				var _stream_id = audio_play_sound(_handle.audioID, _priority, _handle.loop);
				_handle.playId = _stream_id;
				return(_stream_id);
		};
		if (!(variable_struct_exists(_handle, "audioQueue"))) then return(-1);
		// stream loop is handled by refill, not audio_play_sound loop
		caudio_stream_set_loop(_handle, _loop);
		if (variable_struct_exists(_handle, "queueStarts") && (array_length(_handle.queueStarts) > 0)) {
			_handle.playBaseSeconds = (((_handle.queueStarts[0] * 0.5) / _handle.header.sampleRate) * 2);
		};
		var _id = (audio_play_sound(_handle.audioQueue, _priority, false));
		_handle.playId = _id;
		return(_id);
	};
	if (!(variable_struct_exists(_handle, "audioID"))) then return(-1);
	return(audio_play_sound(_handle.audioID, _priority, _loop));
};

function caudio_stream_set_loop(_stream, _loop) {
	if (!is_struct(_stream)) then return(false);
	if ((variable_struct_exists(_stream, "kind")) && ((_stream.kind) == "ogg")) {
		_stream.loop = bool(_loop);
		if (audio_exists(_stream.playId)) then audio_sound_loop(_stream.playId, _stream.loop);
		return(true);
	};
	if ((variable_struct_exists(_stream, "kind")) && ((_stream.kind) == "flac")) {
		return(caudio_stream_set_loop_flac(_stream, _loop));
	};
	return(caudio_stream_set_loop_wav(_stream, _loop));
};

function caudio_stream_seek(_stream, _seconds) {
	if (!is_struct(_stream)) then return(-1);
	if ((variable_struct_exists(_stream, "kind")) && ((_stream.kind) == "ogg")) {
		if (!caudio_stream_is_playable(_stream)) then return(-1);
		var _duration = _stream.header.duration;
		var _target = max(0, _seconds);
		if (_duration > 0) then _target = min(_target, _duration);
		var _sound = audio_exists(_stream.playId) ? _stream.playId : _stream.audioID;
		if (_sound < 0) then return(-1);
		audio_sound_set_track_position(_sound, _target);
		return(_target);
	};
	if ((variable_struct_exists(_stream, "kind")) && ((_stream.kind) == "flac")) {
		var t = (caudio_stream_seek_flac(_stream, _seconds));
		if (t >= 0) {
			_stream.playId = (audio_play_sound(_stream.audioQueue, 0, false));
		};
		return(t);
	};
	var tw = (caudio_stream_seek_wav(_stream, _seconds));
	if (tw >= 0) {
		_stream.playId = (audio_play_sound(_stream.audioQueue, 0, false));
	};
	return(tw);
};

function caudio_stream_get_position(_stream) {
	if (!is_struct(_stream)) then return(0);
	if ((variable_struct_exists(_stream, "kind")) && ((_stream.kind) == "ogg")) {
		if (!caudio_stream_is_playable(_stream)) then return(0);
		var _sound = audio_exists(_stream.playId) ? _stream.playId : _stream.audioID;
		if (_sound < 0) then return(0);
		return(max(0, audio_sound_get_track_position(_sound)));
	};
	if ((variable_struct_exists(_stream, "kind")) && ((_stream.kind) == "flac")) {
		return(caudio_stream_get_position_flac(_stream));
	};
	return(caudio_stream_get_position_wav(_stream));
};

/// Call each Step (and from async). Tops up queue; restarts play after underrun.
/// _max_fills limits work per call (Step should use 1; async can use more).
function caudio_stream_pump(_stream, _min_queued = 5, _max_fills = 1) {
	if (!is_struct(_stream)) then return;
	if ((variable_struct_exists(_stream, "kind")) && ((_stream.kind) == "ogg")) then return;
	if ((variable_struct_exists(_stream, "done")) && _stream.done && ((_stream.queued) <= 0) && !(_stream.loop)) then return;
	
	var n = 0;
	while (((_stream.queued) < _min_queued) && (n < _max_fills) && (caudio_stream_fill(_stream))) {
		n += 1;
	};

	// underrun: play stopped while data remains — restart
	if ((n > 0) && ((_stream.queued) > 0) && variable_struct_exists(_stream, "playId")) {
		var _active = false;
		if (audio_exists(_stream.playId)) {
			_active = (audio_is_playing(_stream.playId) || audio_is_paused(_stream.playId));
		};
		if (!_active) {
			if (variable_struct_exists(_stream, "queueStarts") && (array_length(_stream.queueStarts) > 0)) {
				_stream.playBaseSeconds = (((_stream.queueStarts[0] * 0.5) / _stream.header.sampleRate) * 2);
			};
			_stream.playId = (audio_play_sound(_stream.audioQueue, 0, false));
			if ((_stream.playId) >= 0) {
				show_debug_message($"[CAudio] stream underrun restart q={ _stream.queued }");
			};
		};
	};
};

/* ended */
