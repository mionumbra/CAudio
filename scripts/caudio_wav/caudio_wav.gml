/* began */

/// 工具集
function caudio_wav() {
	static helper = {
		/// 解析 WAV 文件头
        parseHeader: (function(_path) {
			var audioFormat, channels, sampleRate, bits, byteRate, blockAlign, dataOffset, dataSize;
			
			// 准备
			var _id_b, _len;
			var _id_bf = (file_bin_open(_path, 0)); _len = (file_bin_size(_id_bf)); file_bin_close(_id_bf); // 获取文件大小 // TODO: 不支持 HTML5
			
			// 循环
			var _i = 12; while(_i < _len) { // chunk
				_id_b = (buffer_create(8, buffer_fixed, 1));
				buffer_load_partial(_id_b, _path, _i, 8, 0); buffer_seek(_id_b, buffer_seek_start, 0);
				var _chunk_id = (buffer_read(_id_b, buffer_u32));
				var _chunk_size = (buffer_read(_id_b, buffer_u32));
				buffer_delete(_id_b);
				_i += 8;
				
				// chunk
				if (_chunk_id == 0x20746D66) { // "fmt "
					_id_b = (buffer_create(_chunk_size, buffer_fixed, 1));
					buffer_load_partial(_id_b, _path, _i, _chunk_size, 0); buffer_seek(_id_b, buffer_seek_start, 0);
					
					audioFormat = (buffer_read(_id_b, buffer_u16));
					channels = (buffer_read(_id_b, buffer_u16));
					sampleRate = (buffer_read(_id_b, buffer_u32));
					byteRate = (buffer_read(_id_b, buffer_u32));
					blockAlign = (buffer_read(_id_b, buffer_u16));
					bits = (buffer_read(_id_b, buffer_u16));
					
					buffer_delete(_id_b);
				} elif (_chunk_id == 0x61746164) { // "data"
					dataOffset = _i;
					dataSize = _chunk_size;
					break;
				};
				
				//
				_i += _chunk_size;
			};
			
			// 返回
			return({ audioFormat, channels, sampleRate, bits, byteRate, blockAlign, dataOffset, dataSize });
		}),
		
		/// 判断位深类型
		parseAudioChennelType: (function(_channels) {
			return((_channels == 1) ? (audio_mono) : (audio_stereo));
		}),
		
		/// 判断通道类型
		parseBufferDataType: (function(_bits) {
			return((_bits == 8) ? (buffer_u8) : (buffer_s16));
		}),
	};
	
	//
	return(helper);
};


/// 创建 WAV 声音
function caudio_create_sound_wav(_path) {
	static helper = (caudio_wav());
	
	// 获取头数据
	var header = (helper.parseHeader(_path));
	
	// 加载数据
	var _data_size = (header.dataSize), audioBuffer = (buffer_create(_data_size, buffer_fixed, 1));
	buffer_load_partial(audioBuffer, _path, (header.dataOffset), _data_size, 0);
	
	// 创建声音
	var audioID = (audio_create_buffer_sound(audioBuffer, (helper.parseBufferDataType(header.bits)), (header.sampleRate), 0, _data_size, (helper.parseAudioChennelType(header.channels))));
	return({ audioID, header, audioBuffer });
};

/// 创建 WAV 声音 (流式)
function caudio_create_sound_stream(path) {
	static helper = (caudio_wav());
	
	// 获取头数据
	var header = (helper.parseHeader(path));
	
	// 创建声音 (队列)
	var audioQueue = (audio_create_play_queue((helper.parseBufferDataType(header.bits)), (header.sampleRate), (helper.parseAudioChennelType(header.channels))));
	return({ audioQueue, header, path });
};

/* ended */