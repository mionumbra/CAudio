/**/
enum CAUDIO_AUDIO_TYPE {
	IDK,
	WAV
};

/// 工具集
function caudio_create() {
	static helper = {
		
		/// 识别音频头
		findHeader: (function(_path) {
			// 读取文件头
			var _sig32, _id_b = (buffer_create(16, buffer_fixed, 1));
			buffer_load_partial(_id_b, _path, 0, 16, 0);
			_sig32 = (buffer_read(_id_b, buffer_u32));
			buffer_delete(_id_b);
			
			// 识别文件头
			if (_sig32 == 0x46464952) then return(CAUDIO_AUDIO_TYPE.WAV); // WAV
			else return(CAUDIO_AUDIO_TYPE.IDK); // 何意味
		})
		
	};
	
	//
	return(helper);
};

/// 创建声音
function caudio_create_sound(_path) {
	static helper = (caudio_create());
	
	//
	var _r;
	switch(helper.findHeader(_path)) {
		case(CAUDIO_AUDIO_TYPE.WAV): 
			_r = (caudio_create_sound_wav(_path));
			break;
	};
};

/// 创建声音 (流式)
function caudio_create_stream(_path) {
	static helper = (caudio_create());
	
};

/**/