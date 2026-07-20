/* began */

/// 主逻辑
function caudio_wav() {
	static helper = {
		/// 解析 WAV 文件头
		parseHeader: (function(_path) {
			var audioFormat = -1, channels = -1, sampleRate = -1, bits = -1, byteRate = -1, blockAlign = -1;
			var dataOffset = -1, dataSize = -1;
			var
				validBits = -1,
				channelMask = -1
			;
			var _len;
			var _found_fmt = false;
			
			var _id_bf = (file_bin_open(_path, 0));
			if (_id_bf < 0) {
				show_debug_message("[CAudio] [WAV] E: Cannot open file.");
				return(-1);
			};
			_len = (file_bin_size(_id_bf));
			file_bin_close(_id_bf);
			if (_len < 12) {
				show_debug_message("[CAudio] [WAV] E: File too small.");
				return(-1);
			};
			
			var _id_b = (buffer_create(12, buffer_fixed, 1));
			buffer_load_partial(_id_b, _path, 0, 12, 0);
			buffer_seek(_id_b, buffer_seek_start, 0);
			var _riff_id = (buffer_read(_id_b, buffer_u32));
			var _riff_size = (buffer_read(_id_b, buffer_u32));
			var _wave_id = (buffer_read(_id_b, buffer_u32));
			buffer_delete(_id_b);
			if ((_riff_id != 0x46464952) || (_wave_id != 0x45564157)) {
				show_debug_message("[CAudio] [WAV] E: Not a valid WAV file.");
				return(-1);
			};
			
			var _i = 12; while (_i + 8 <= _len) {
				_id_b = (buffer_create(8, buffer_fixed, 1));
				buffer_load_partial(_id_b, _path, _i, 8, 0);
				buffer_seek(_id_b, buffer_seek_start, 0);
				var _chunk_id = (buffer_read(_id_b, buffer_u32));
				var _chunk_size = (buffer_read(_id_b, buffer_u32));
				buffer_delete(_id_b);
				_i += 8;
				
				if (_i + _chunk_size > _len) {
					show_debug_message("[CAudio] [WAV] E: Truncated chunk.");
					return(-1);
				};
				
				if (_chunk_id == 0x20746D66) {
					if (_chunk_size < 16) {
						show_debug_message("[CAudio] [WAV] E: fmt chunk too small.");
						return(-1);
					};
					var _fmt_size = (min(_chunk_size, 40));
					_id_b = (buffer_create(_fmt_size, buffer_fixed, 1));
					buffer_load_partial(_id_b, _path, _i, _fmt_size, 0);
					buffer_seek(_id_b, buffer_seek_start, 0);
					
					audioFormat = (buffer_read(_id_b, buffer_u16));
					channels = (buffer_read(_id_b, buffer_u16));
					sampleRate = (buffer_read(_id_b, buffer_u32));
					byteRate = (buffer_read(_id_b, buffer_u32));
					blockAlign = (buffer_read(_id_b, buffer_u16));
					bits = (buffer_read(_id_b, buffer_u16));
					_found_fmt = true;
					
					if (audioFormat == 65534) {
						if (_chunk_size >= 18) {
							var _cb_size = (buffer_read(_id_b, buffer_u16));
							if ((_cb_size >= 22) && (_chunk_size >= 40)) {
								validBits = (buffer_read(_id_b, buffer_u16));
								channelMask = (buffer_read(_id_b, buffer_u32));
								var _subformat = (buffer_read(_id_b, buffer_u32));
								var _guid_tail = (array_create(12));
								var _guid_read = 0; while (_guid_read < 12) {
									_guid_tail[_guid_read] = (buffer_read(_id_b, buffer_u8));
									_guid_read += 1;
								};
								var _standard_tail = [0x00, 0x00, 0x10, 0x00, 0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71];
								var _standard_guid = true;
								var _guid_index = 0; while (_guid_index < 12) {
									if (_guid_tail[_guid_index] != _standard_tail[_guid_index]) then _standard_guid = false;
									_guid_index += 1;
								};
								if (_standard_guid) then audioFormat = _subformat;
								else show_debug_message($"[CAudio] [WAV] W: Non-standard SubFormat GUID tail={ _guid_tail }.");
								if ((validBits > 0) && (validBits < bits)) {
									show_debug_message($"[CAudio] [WAV] W: validBits ({ validBits }) < container bits ({ bits }), audio may contain padding.");
								};
							};
						};
					};
					
					buffer_delete(_id_b);
				} elif (_chunk_id == 0x61746164) {
					dataOffset = _i;
					dataSize = _chunk_size;
					if (_found_fmt) then break;
				};
				
				_i += _chunk_size; if (_chunk_size & 1) then _i ++;
			};
			
			if (!_found_fmt) {
				show_debug_message("[CAudio] [WAV] E: Missing fmt chunk.");
				return(-1);
			};
			if ((dataOffset < 0) || (dataSize < 0)) {
				show_debug_message("[CAudio] [WAV] E: Missing data chunk.");
				return(-1);
			};
			if ((sampleRate <= 0) || (channels <= 0) || (bits <= 0) || (blockAlign <= 0)) {
				show_debug_message("[CAudio] [WAV] E: Invalid fmt fields.");
				return(-1);
			};
			if ((audioFormat != 1) && (audioFormat != 3)) {
				show_debug_message($"[CAudio] [WAV] E: Unsupported audioFormat={ audioFormat }.");
				return(-1);
			};
			if (((audioFormat == 1) && (bits != 8) && (bits != 16) && (bits != 24) && (bits != 32)) || ((audioFormat == 3) && (bits != 32))) {
				show_debug_message($"[CAudio] [WAV] E: Unsupported format={ audioFormat } bit depth={ bits }.");
				return(-1);
			};
			if ((channels != 1) && (channels != 2)) {
				show_debug_message($"[CAudio] [WAV] E: Unsupported channel count { channels }; only mono and stereo are supported.");
				return(-1);
			};
			var expectedBlockAlign = (channels * (bits div 8));
			if (blockAlign != expectedBlockAlign) {
				show_debug_message($"[CAudio] [WAV] E: Invalid blockAlign { blockAlign }; expected { expectedBlockAlign }.");
				return(-1);
			};
			if (byteRate != sampleRate * blockAlign) {
				show_debug_message($"[CAudio] [WAV] E: Invalid byteRate { byteRate }; expected { sampleRate * blockAlign }.");
				return(-1);
			};
			if ((dataSize % blockAlign) != 0) {
				show_debug_message($"[CAudio] [WAV] E: data chunk size { dataSize } is not frame-aligned to { blockAlign } bytes.");
				return(-1);
			};
			
			var outBits = (((audioFormat == 1) && (bits == 8)) ? 8 : 16);
			var outBlockAlign = (channels * (outBits div 8));
			var outByteRate = (sampleRate * outBlockAlign);
			var convert = ((audioFormat == 3) || (bits > 16));
			var duration = ((byteRate > 0) ? (((dataSize * 0.5) / byteRate) * 2) : 0);
			return({ audioFormat, channels, sampleRate, bits, byteRate, blockAlign, dataOffset, dataSize, channelMask, validBits, outBits, outBlockAlign, outByteRate, convert, duration });
		}),
		
		parseAudioChannelType: (function(_channels) {
			switch (_channels) {
				case(1): return(audio_mono);
				case(2): return(audio_stereo);
				default:
					return(-1);
			};
		}),
		
		parseBufferDataType: (function(_bits) {
			switch (_bits) {
				case(8): return(buffer_u8);
				case(16): return(buffer_s16);
				default:
					return(-1);
			};
		}),
		
		calcStreamChunkSize: (function(_header, _seconds = 0.1) {
			var _ba = (max(1, _header.blockAlign));
			var _raw = (floor((_header.sampleRate) * _ba * _seconds));
			var _cs = (floor(_raw / _ba) * _ba);
			if (_cs < _ba) then _cs = _ba;
			return(_cs);
		}),

		convertPcm: function(_source, _sourceSize, _header) {
			var frames = (_sourceSize div _header.blockAlign);
			var outputSize = (frames * _header.outBlockAlign);
			var output = (buffer_create(outputSize, buffer_fixed, 1));
			var sourcePos = 0;
			var outputPos = 0;
			var sampleCount = (frames * _header.channels);
			var i = 0; while (i < sampleCount) {
				var sample = 0;
				if (_header.audioFormat == 3) {
					var value = (buffer_peek(_source, sourcePos, buffer_f32));
					sample = (clamp(round(value * 32768), -32768, 32767));
					sourcePos += 4;
				} elif (_header.bits == 24) {
					var packed = (buffer_peek(_source, sourcePos, buffer_u8)
						| (buffer_peek(_source, sourcePos + 1, buffer_u8) << 8)
						| (buffer_peek(_source, sourcePos + 2, buffer_u8) << 16));
					if ((packed & 0x800000) != 0) then packed -= 0x1000000;
					sample = (packed >> 8);
					sourcePos += 3;
				} else {
					sample = (buffer_peek(_source, sourcePos, buffer_s32) >> 16);
					sourcePos += 4;
				};
				buffer_poke(output, outputPos, buffer_s16, sample);
				outputPos += 2;
				i += 1;
			};
			return(output);
		},
	};
	
	return(helper);
};


function caudio_create_sound_wav(_path) {
	static helper = (caudio_wav());
	var header = (helper.parseHeader(_path));
	if (header == -1) then return(-1);
	
	var _source_size = (header.dataSize), sourceBuffer = (buffer_create(_source_size, buffer_fixed, 1));
	buffer_load_partial(sourceBuffer, _path, (header.dataOffset), _source_size, 0);
	var audioBuffer = sourceBuffer;
	var _data_size = _source_size;
	if (header.convert) {
		audioBuffer = (helper.convertPcm(sourceBuffer, _source_size, header));
		buffer_delete(sourceBuffer);
		_data_size = (buffer_get_size(audioBuffer));
	};
	
	var audioID = (audio_create_buffer_sound(audioBuffer, (helper.parseBufferDataType(header.outBits)), (header.sampleRate), 0, _data_size, (helper.parseAudioChannelType(header.channels))));
	if (audioID < 0) {
		buffer_delete(audioBuffer);
		show_debug_message("[CAudio] [WAV] E: audio_create_buffer_sound failed.");
		return(-1);
	};
	header.outputDataSize = _data_size;
	return({ audioID, header, audioBuffer, path: _path, kind: "wav", mode: "buffer" });
};

function caudio_create_stream_wav(_path) {
	static helper = (caudio_wav());
	var header = (helper.parseHeader(_path));
	if (header == -1) then return(-1);
	
	var audioQueue = (audio_create_play_queue((helper.parseBufferDataType(header.outBits)), (header.sampleRate), (helper.parseAudioChannelType(header.channels))));
	if (audioQueue < 0) {
		show_debug_message("[CAudio] [WAV] E: audio_create_play_queue failed.");
		return(-1);
	};
	var chunkSize = (helper.calcStreamChunkSize(header, 0.1));
	return({
		audioQueue,
		header,
		path: _path,
		chunkSize,
		dataOffset: (header.dataOffset),
		dataEnd: ((header.dataOffset) + (header.dataSize)),
		dataStart: (header.dataOffset),
		queued: 0,
		queueBuffers: [],
		queueStarts: [],
		queueSamples: [],
		queueGeneration: 0,
		retiredQueues: [],
		playBaseSeconds: 0,
		done: false,
		loop: false,
		playId: -1,
		kind: "wav",
		mode: "stream",
	});
};

function caudio_stream_fill_wav(_stream) {
	static helper = (caudio_wav());
	if (!is_struct(_stream)) then return(false);
	if (variable_struct_exists(_stream, "done") && _stream.done) then return(false);
	var _remain = ((_stream.dataEnd) - (_stream.dataOffset));
	if (_remain <= 0) {
		if (_stream.loop) {
			_stream.dataOffset = (_stream.dataStart);
			_remain = ((_stream.dataEnd) - (_stream.dataOffset));
		} else {
			_stream.done = true;
			return(false);
		};
	};
	
	var _cs = (min(_remain, _stream.chunkSize));
	var _ba = (max(1, _stream.header.blockAlign));
	if ((_cs >= _ba) && ((_cs % _ba) != 0)) {
		_cs = (floor(_cs / _ba) * _ba);
	};
	if (_cs <= 0) then return(false);
	
	var _start = ((_stream.dataOffset) - (_stream.dataStart));
	var _source = (buffer_create(_cs, buffer_fixed, 1));
	buffer_load_partial(_source, (_stream.path), (_stream.dataOffset), _cs, 0);
	_stream.dataOffset += _cs;
	var _id_b = _source;
	var _queue_size = _cs;
	if (_stream.header.convert) {
		_id_b = (helper.convertPcm(_source, _cs, _stream.header));
		buffer_delete(_source);
		_queue_size = (buffer_get_size(_id_b));
	};
	audio_queue_sound((_stream.audioQueue), _id_b, 0, _queue_size);
	array_push(_stream.queueBuffers, _id_b);
	array_push(_stream.queueStarts, (_start div _ba));
	array_push(_stream.queueSamples, (_cs div _ba));
	_stream.queued = (array_length(_stream.queueBuffers));
	return(true);
};

function caudio_stream_prime_wav(_stream, _min_queued = 3) {
	if (!is_struct(_stream)) then return(0);
	var _n = 0;
	while (((_stream.queued) < _min_queued) && (caudio_stream_fill_wav(_stream))) {
		_n += 1;
	};
	return(_n);
};

function caudio_stream_on_async_wav(_stream, _async_map, _min_queued = 3) {
	if (!is_struct(_stream)) then return;
	var _bid = (_async_map[? "buffer_id"]);
	var _qid = (_async_map[? "queue_id"]);
	var _index = (array_get_index(_stream.queueBuffers, _bid));
	if ((_qid == (_stream.audioQueue)) && (_index >= 0)) {
		var _completed_sample = (_stream.queueStarts[_index] + _stream.queueSamples[_index]);
		if (buffer_exists(_bid)) then buffer_delete(_bid);
		array_delete(_stream.queueBuffers, _index, 1);
		array_delete(_stream.queueStarts, _index, 1);
		array_delete(_stream.queueSamples, _index, 1);
		_stream.queued = (array_length(_stream.queueBuffers));
		var _base_sample = ((_stream.queued > 0) ? _stream.queueStarts[0] : _completed_sample);
		_stream.playBaseSeconds = (((_base_sample * 0.5) / _stream.header.sampleRate) * 2);
		if ((_stream.queued) < _min_queued) then caudio_stream_fill_wav(_stream);
		return;
	};
	var _queue_index = 0;
	while (_queue_index < array_length(_stream.retiredQueues)) {
		var _retired_queue = _stream.retiredQueues[_queue_index];
		if ((_retired_queue.queueId) == _qid) {
			var _retired_buffer = (array_get_index(_retired_queue.buffers, _bid));
			if (_retired_buffer >= 0) {
				if ((_index < 0) && buffer_exists(_bid)) then buffer_delete(_bid);
				array_delete(_retired_queue.buffers, _retired_buffer, 1);
				if (array_length(_retired_queue.buffers) == 0) then array_delete(_stream.retiredQueues, _queue_index, 1);
				return;
			};
		};
		_queue_index += 1;
	};
};


function caudio_stream_free_wav(_stream) {
	if (!is_struct(_stream)) then return;
	if (audio_exists(_stream.playId)) then audio_stop_sound(_stream.playId);
	_stream.playId = -1;
	var _retired_index = 0;
	while (_retired_index < array_length(_stream.retiredQueues)) {
		var _retired = _stream.retiredQueues[_retired_index];
		caudio_retired_queue_register(_retired.queueId, _retired.buffers);
		_retired_index += 1;
	};
	_stream.retiredQueues = [];
	if (variable_struct_exists(_stream, "audioQueue") && ((_stream.audioQueue) >= 0)) {
		caudio_retired_queue_register(_stream.audioQueue, _stream.queueBuffers);
		audio_free_play_queue(_stream.audioQueue);
		_stream.audioQueue = -1;
	};
	_stream.done = true;
	_stream.queued = 0;
	_stream.queueBuffers = [];
	_stream.queueStarts = [];
	_stream.queueSamples = [];
};

function caudio_free_sound_wav(_sound) {
	if (!is_struct(_sound)) then return;
	if (variable_struct_exists(_sound, "audioID") && audio_exists(_sound.audioID)) {
		audio_stop_sound(_sound.audioID);
		audio_free_buffer_sound(_sound.audioID);
		_sound.audioID = -1;
	};
	if (variable_struct_exists(_sound, "audioBuffer") && buffer_exists(_sound.audioBuffer)) {
		buffer_delete(_sound.audioBuffer);
		_sound.audioBuffer = -1;
	};
};


function caudio_stream_set_loop_wav(_stream, _loop) {
	if (!is_struct(_stream)) then return(false);
	_stream.loop = (bool(_loop));
	if (_stream.loop && _stream.done) then _stream.done = false;
	return(true);
};

function caudio_stream_seek_wav(_stream, _seconds) {
	static helper = (caudio_wav());
	if (!is_struct(_stream)) then return(-1);
	var h = (_stream.header);
	if ((h.byteRate) <= 0) then return(-1);
	
	var targetByte = (max(0, floor(_seconds * (h.byteRate))));
	var ba = (max(1, h.blockAlign));
	targetByte = (floor(targetByte / ba) * ba);
	var dataSize = ((h.dataSize));
	if (targetByte >= dataSize) {
		if (_stream.loop) then targetByte = 0;
		else targetByte = (max(0, dataSize - ba));
	};
	
	var btype = (helper.parseBufferDataType(h.outBits));
	var ctype = (helper.parseAudioChannelType(h.channels));
	var replacementQueue = (audio_create_play_queue(btype, (h.sampleRate), ctype));
	if (replacementQueue < 0) then return(-1);

	if ((_stream.audioQueue) >= 0) {
		if (audio_exists(_stream.playId)) then audio_stop_sound(_stream.playId);
		if (array_length(_stream.queueBuffers) > 0) then array_push(_stream.retiredQueues, { queueId: _stream.audioQueue, generation: _stream.queueGeneration, buffers: _stream.queueBuffers });
		audio_free_play_queue(_stream.audioQueue);
	};
	_stream.audioQueue = replacementQueue;
	_stream.queueGeneration += 1;
	_stream.dataOffset = ((_stream.dataStart) + targetByte);
	_stream.done = false;
	_stream.queued = 0;
	_stream.queueBuffers = [];
	_stream.queueStarts = [];
	_stream.queueSamples = [];
	_stream.playBaseSeconds = (((targetByte * 0.5) / h.byteRate) * 2);
	_stream.playId = -1;
	
	var primed = (caudio_stream_prime_wav(_stream, 5));
	var pos = (((targetByte * 0.5) / h.byteRate) * 2);
	show_debug_message($"[CAudio] [WAV] seek t={ _seconds }s -> { pos }s primed={ primed }");
	return(pos);
};

function caudio_stream_get_position_wav(_stream) {
	if (!is_struct(_stream)) then return(0);
	var h = (_stream.header);
	if ((h.byteRate) <= 0) then return(0);
	var pos = (((_stream.dataOffset) - (_stream.dataStart)) / (h.byteRate));
	if (audio_exists(_stream.playId)) {
		pos = ((_stream.playBaseSeconds) + audio_sound_get_track_position(_stream.playId));
	} elif ((array_length(_stream.queueStarts)) > 0) {
		pos = (((_stream.queueStarts[0] * 0.5) / h.sampleRate) * 2);
	};
	var duration = (h.duration);
	if (_stream.loop && (duration > 0)) {
		var _total_samples = (h.dataSize div h.blockAlign);
		var _position_sample = floor(pos * h.sampleRate);
		_position_sample -= (floor(_position_sample / _total_samples) * _total_samples);
		pos = (_position_sample / h.sampleRate);
		pos = min(pos, max(0, duration - (1.0 / h.sampleRate)));
	}
	elif (duration > 0) then pos = (min(pos, duration));
	return(max(0, pos));
};

/* ended */
