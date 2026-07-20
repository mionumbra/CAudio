_test_paths = [
	"./IF = Infinity.wav",
	"./test.flac",
	"./边境之城的童谣.flac",
];
_test_kinds = ["wav", "flac", "flac"];
_test_index = -1;
_test_phase = 0;
_test_frames = 0;
_test_failures = 0;
_test_case = "";
_audio = undefined;
_ins = -1;
_queue_min = 1;
_stress_started = false;
_stress_seeks = 0;
_registry_buffer = -1;
_registry_pending_before = 0;
_position_started = false;
_position_last = 0;
_position_wrapped = false;

_test_check = function(_condition, _label) {
	if (_condition) {
		show_debug_message($"[CAudioTest] PASS { _test_case }: { _label }");
	} else {
		_test_failures += 1;
		show_debug_message($"[CAudioTest] FAIL { _test_case }: { _label }");
	};
	return(_condition);
};

var _flac_fixtures = [
	["./caudio_pcm_fixture.flac", "338f754d34a7bc4c1ad260d680772a20", 16, 2],
	["./caudio_flac_fixed_mono.flac", "2b7f0e2a29dde8278db61fa710358cf4", 16, 1],
	["./caudio_flac_lpc_midside.flac", "0ceb342557827d5eca9694c416a4c5f3", 16, 2],
	["./caudio_flac_24bit.flac", "a5e879b64036262a1c1ff1ed6ca5fc84", 24, 2],
	["./caudio_flac_constant.flac", "73f8f146ccbfa63f23709a88cbcf07ff", 16, 1],
	["./caudio_flac_8bit.flac", "3cae6f34a0a4f69ff7cf85044f2c05ca", 8, 1],
	["./caudio_flac_verbatim.flac", "768ed4fad23f1a3a675476def2339be0", 16, 1],
];
var _fixture_index = 0;
while (_fixture_index < array_length(_flac_fixtures)) {
	var _fixture = _flac_fixtures[_fixture_index];
	_test_case = $"{ _fixture[0] } full decode";
	var _decode_started = get_timer();
	var _decoded = caudio_create_sound(_fixture[0]);
	var _decode_ms = (get_timer() - _decode_started) / 1000;
	if (_test_check(is_struct(_decoded), $"create buffer sound ({ _decode_ms }ms)")) {
		_test_check(_decoded.kind == "flac" && _decoded.mode == "buffer", "buffer handle metadata");
		_test_check(_decoded.header.bits == _fixture[2] && _decoded.header.channels == _fixture[3], "source format metadata");
		var _pcm_md5 = buffer_md5(_decoded.audioBuffer, 0, _decoded.header.dataSize);
		_test_check(_pcm_md5 == _fixture[1], $"PCM MD5={ _pcm_md5 }");
		caudio_free(_decoded);
	};
	_fixture_index += 1;
};

var _unknown_source = buffer_load("./caudio_flac_fixed_mono.flac");
var _unknown_total_path = temp_directory + "caudio_flac_unknown_total.flac";
buffer_poke(_unknown_source, 21, buffer_u8, buffer_peek(_unknown_source, 21, buffer_u8) & 0xF0);
var _unknown_total_byte = 22;
while (_unknown_total_byte <= 25) {
	buffer_poke(_unknown_source, _unknown_total_byte, buffer_u8, 0);
	_unknown_total_byte += 1;
};
buffer_save(_unknown_source, _unknown_total_path);
buffer_delete(_unknown_source);
_test_case = "FLAC unknown total samples";
var _unknown_total_sound = caudio_create_sound(_unknown_total_path);
if (_test_check(is_struct(_unknown_total_sound), "create unknown-length buffer sound")) {
	_test_check(_unknown_total_sound.header.totalSamples == 0 && _unknown_total_sound.header.decodedSamples == 8000, "decode until physical EOF");
	var _unknown_total_md5 = buffer_md5(_unknown_total_sound.audioBuffer, 0, _unknown_total_sound.header.dataSize);
	_test_check(_unknown_total_md5 == "2b7f0e2a29dde8278db61fa710358cf4", $"unknown-length PCM MD5={ _unknown_total_md5 }");
	caudio_free(_unknown_total_sound);
};
var _unknown_total_stream = caudio_create_stream(_unknown_total_path);
if (_test_check(is_struct(_unknown_total_stream), "create unknown-length stream")) {
	while (caudio_stream_fill(_unknown_total_stream)) {};
	_test_check(_unknown_total_stream.totalSamples == 8000 && _unknown_total_stream.header.totalSamples == 8000, "stream discovers total samples at clean EOF");
	_test_check(_unknown_total_stream.header.duration > 0.249 && _unknown_total_stream.header.duration < 0.251, $"stream discovers duration at clean EOF value={ _unknown_total_stream.header.duration }");
	caudio_free(_unknown_total_stream);
};

var _wav_helper = caudio_wav();
show_debug_message("[CAudioTest] WAV conversion matrix v2");
var _ext_source_header = _wav_helper.parseHeader("./caudio_wav_pcm24.wav");
var _ext_source = buffer_create(_ext_source_header.dataSize, buffer_fixed, 1);
buffer_load_partial(_ext_source, "./caudio_wav_pcm24.wav", _ext_source_header.dataOffset, _ext_source_header.dataSize, 0);
var _ext_frames = _ext_source_header.dataSize div _ext_source_header.blockAlign;
var _ext_data_size = _ext_frames * _ext_source_header.channels * 4;
var _extensible = buffer_create(68 + _ext_data_size, buffer_fixed, 1);
buffer_poke(_extensible, 0, buffer_u32, 0x46464952);
buffer_poke(_extensible, 4, buffer_u32, 60 + _ext_data_size);
buffer_poke(_extensible, 8, buffer_u32, 0x45564157);
buffer_poke(_extensible, 12, buffer_u32, 0x20746D66);
buffer_poke(_extensible, 16, buffer_u32, 40);
buffer_poke(_extensible, 20, buffer_u16, 65534);
buffer_poke(_extensible, 22, buffer_u16, _ext_source_header.channels);
buffer_poke(_extensible, 24, buffer_u32, _ext_source_header.sampleRate);
buffer_poke(_extensible, 28, buffer_u32, _ext_source_header.sampleRate * _ext_source_header.channels * 4);
buffer_poke(_extensible, 32, buffer_u16, _ext_source_header.channels * 4);
buffer_poke(_extensible, 34, buffer_u16, 32);
buffer_poke(_extensible, 36, buffer_u16, 22);
buffer_poke(_extensible, 38, buffer_u16, 24);
buffer_poke(_extensible, 40, buffer_u32, (_ext_source_header.channels == 1) ? 4 : 3);
buffer_poke(_extensible, 44, buffer_u32, 1);
var _ext_guid_tail = [0x00, 0x00, 0x10, 0x00, 0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71];
var _ext_guid_index = 0;
while (_ext_guid_index < array_length(_ext_guid_tail)) {
	buffer_poke(_extensible, 48 + _ext_guid_index, buffer_u8, _ext_guid_tail[_ext_guid_index]);
	_ext_guid_index += 1;
};
buffer_poke(_extensible, 60, buffer_u32, 0x61746164);
buffer_poke(_extensible, 64, buffer_u32, _ext_data_size);
var _ext_sample_count = _ext_frames * _ext_source_header.channels;
var _ext_sample_index = 0;
while (_ext_sample_index < _ext_sample_count) {
	var _ext_source_pos = _ext_sample_index * 3;
	var _ext_sample = (buffer_peek(_ext_source, _ext_source_pos, buffer_u8)
		| (buffer_peek(_ext_source, _ext_source_pos + 1, buffer_u8) << 8)
		| (buffer_peek(_ext_source, _ext_source_pos + 2, buffer_u8) << 16));
	if ((_ext_sample & 0x800000) != 0) then _ext_sample -= 0x1000000;
	buffer_poke(_extensible, 68 + (_ext_sample_index * 4), buffer_s32, _ext_sample << 8);
	_ext_sample_index += 1;
};
var _extensible_path = temp_directory + "caudio_wav_extensible_24in32.wav";
buffer_save(_extensible, _extensible_path);
buffer_delete(_extensible);
buffer_delete(_ext_source);

var _converted_wavs = [
	["./caudio_wav_float32.wav", "d30c0288dee83790179802654e78de73", 32, 1],
	["./caudio_wav_pcm24.wav", "2af3e7232cbe925e511776d7d1702974", 24, 1],
	["./caudio_wav_pcm32.wav", "b468075c9de392a26acae55786e99307", 32, 2],
	[_extensible_path, "2af3e7232cbe925e511776d7d1702974", 32, 1, 24],
];
var _wav_index = 0;
while (_wav_index < array_length(_converted_wavs)) {
	var _wav_fixture = _converted_wavs[_wav_index];
	_test_case = _wav_fixture[0];
	var _wav_sound = caudio_create_sound(_test_case);
	if (_test_check(is_struct(_wav_sound), "converted buffer sound created")) {
		_test_check(_wav_sound.header.bits == _wav_fixture[2] && _wav_sound.header.channels == _wav_fixture[3], "source WAV metadata");
		if (array_length(_wav_fixture) > 4) then _test_check(_wav_sound.header.validBits == _wav_fixture[4], "WAVEFORMATEXTENSIBLE valid bits");
		_test_check(_wav_sound.header.outBits == 16 && _wav_sound.header.convert, "s16 conversion metadata");
		var _wav_md5 = buffer_md5(_wav_sound.audioBuffer, 0, _wav_sound.header.outputDataSize);
		_test_check(_wav_md5 == _wav_fixture[1], $"converted PCM MD5={ _wav_md5 }");
		caudio_free(_wav_sound);
	};
	var _wav_stream = caudio_create_stream(_test_case);
	if (_test_check(is_struct(_wav_stream), "converted stream created")) {
		var _stream_expected_size = ((_wav_stream.header.dataSize div _wav_stream.header.blockAlign) * _wav_stream.header.outBlockAlign);
		var _stream_pcm = buffer_create(_stream_expected_size, buffer_fixed, 1);
		var _stream_write = 0;
		while (caudio_stream_fill(_wav_stream)) {
			var _queue_index = array_length(_wav_stream.queueBuffers) - 1;
			var _queue_size = _wav_stream.queueSamples[_queue_index] * _wav_stream.header.outBlockAlign;
			buffer_copy(_wav_stream.queueBuffers[_queue_index], 0, _queue_size, _stream_pcm, _stream_write);
			_stream_write += _queue_size;
		};
		_test_check(_stream_write == _stream_expected_size, $"stream converted bytes={ _stream_write }");
		var _stream_md5 = buffer_md5(_stream_pcm, 0, _stream_write);
		_test_check(_stream_md5 == _wav_fixture[1], $"stream converted PCM MD5={ _stream_md5 }");
		buffer_delete(_stream_pcm);
		caudio_free(_wav_stream);
	};
	_wav_index += 1;
};

var _invalid_wavs = ["./caudio_wav_5_1.wav"];
var _invalid_index = 0;
while (_invalid_index < array_length(_invalid_wavs)) {
	_test_case = _invalid_wavs[_invalid_index];
	_test_check(caudio_create_sound(_test_case) == -1, "buffer sound rejects unsupported WAV");
	_test_check(caudio_create_stream(_test_case) == -1, "stream rejects unsupported WAV");
	_invalid_index += 1;
};

var _unaligned_source = buffer_load("./caudio_wav_pcm24.wav");
var _unaligned_size = buffer_get_size(_unaligned_source);
var _unaligned_wav = buffer_create(_unaligned_size + 1, buffer_fixed, 1);
buffer_copy(_unaligned_source, 0, _unaligned_size, _unaligned_wav, 0);
var _unaligned_header = _wav_helper.parseHeader("./caudio_wav_pcm24.wav");
buffer_poke(_unaligned_wav, 4, buffer_u32, buffer_peek(_unaligned_wav, 4, buffer_u32) + 1);
buffer_poke(_unaligned_wav, _unaligned_header.dataOffset - 4, buffer_u32, _unaligned_header.dataSize + 1);
buffer_poke(_unaligned_wav, _unaligned_size, buffer_u8, 0);
var _unaligned_path = temp_directory + "caudio_wav_unaligned.wav";
buffer_save(_unaligned_wav, _unaligned_path);
buffer_delete(_unaligned_wav);
buffer_delete(_unaligned_source);
_test_case = "WAV incomplete sample frame";
_test_check(caudio_create_sound(_unaligned_path) == -1, "buffer sound rejects unaligned data chunk");
_test_check(caudio_create_stream(_unaligned_path) == -1, "stream rejects unaligned data chunk");

_test_case = "short stream loop latch";
var _short_wav = caudio_create_stream("./caudio_wav_pcm24.wav");
if (_test_check(is_struct(_short_wav), "create short WAV stream")) {
	caudio_stream_prime(_short_wav, 5);
	_test_check(_short_wav.done, "non-looping WAV prime reaches EOF");
	_test_check(caudio_stream_set_loop(_short_wav, true) && !_short_wav.done, "enabling WAV loop clears clean EOF");
	_test_check(caudio_stream_fill(_short_wav), "WAV can refill after loop enabled");
	caudio_free(_short_wav);
	_test_check(_short_wav.playId == -1, "WAV free clears play instance");
};
var _short_flac = caudio_create_stream("./caudio_flac_fixed_mono.flac");
if (_test_check(is_struct(_short_flac), "create short FLAC stream")) {
	caudio_stream_prime(_short_flac, 5);
	_test_check(_short_flac.done, "non-looping FLAC prime reaches EOF");
	_test_check(caudio_stream_set_loop(_short_flac, true) && !_short_flac.done, "enabling FLAC loop clears clean EOF");
	_test_check(caudio_stream_fill(_short_flac), "FLAC can refill after loop enabled");
	caudio_free(_short_flac);
	_test_check(_short_flac.playId == -1, "FLAC free clears play instance");
};

_test_case = "WAV negative seek";
var _negative_seek_stream = caudio_create_stream("./caudio_wav_pcm24.wav");
if (_test_check(is_struct(_negative_seek_stream), "create negative-seek stream")) {
	var _negative_seek = caudio_stream_seek(_negative_seek_stream, -1);
	_test_check(_negative_seek == 0 && _negative_seek_stream.dataOffset >= _negative_seek_stream.dataStart, "negative seek clamps to start");
	_test_check(array_length(_negative_seek_stream.queueStarts) > 0 && _negative_seek_stream.queueStarts[0] == 0, "negative seek queues first sample");
	caudio_free(_negative_seek_stream);
};

_test_case = "FLAC streaming CRC benchmark";
var _crc_stream = caudio_create_stream("./test.flac");
if (_test_check(is_struct(_crc_stream), "create benchmark stream")) {
	var _crc_started = get_timer();
	var _crc_filled = caudio_stream_fill(_crc_stream);
	var _crc_ms = (get_timer() - _crc_started) / 1000;
	_test_check(_crc_filled, $"decode one fill in { _crc_ms }ms");
	_test_check(_crc_stream.bitReader.crcBufferHits > 0, $"CRC window hits={ _crc_stream.bitReader.crcBufferHits }");
	_test_check(_crc_stream.bitReader.crcFileLoads <= 1, $"CRC fallback file loads={ _crc_stream.bitReader.crcFileLoads }");
	show_debug_message($"[CAudioTest] CRC optimized hits={ _crc_stream.bitReader.crcBufferHits } fileLoads={ _crc_stream.bitReader.crcFileLoads } ms={ _crc_ms }");
	caudio_free(_crc_stream);
};

_test_case = "./caudio_ogg_vorbis.ogg";
_test_check(caudio_create_sound(_test_case) == -1, "OGG buffer sound is explicitly unsupported");
var _ogg_stream = caudio_create_stream(_test_case);
if (_test_check(is_struct(_ogg_stream), "create native OGG stream")) {
	_test_check(_ogg_stream.kind == "ogg" && _ogg_stream.mode == "stream", "OGG stream metadata");
	_test_check(caudio_stream_is_playable(_ogg_stream) && _ogg_stream.playable, "OGG stream is playable");
	_test_check(_ogg_stream.header.duration > 0, $"OGG duration={ _ogg_stream.header.duration }");
	_test_check(caudio_stream_prime(_ogg_stream, 3) == 0, "OGG prime is a safe no-op");
	var _ogg_play = caudio_play(_ogg_stream, 0, false);
	_test_check(_ogg_play >= 0, "OGG playback started");
	var _ogg_target = min(0.05, _ogg_stream.header.duration * 0.5);
	var _ogg_seek = caudio_stream_seek(_ogg_stream, _ogg_target);
	_test_check(abs(_ogg_seek - _ogg_target) < 0.001, "OGG seek accepted");
	_test_check(caudio_stream_get_position(_ogg_stream) >= 0, "OGG position available");
	_test_check(caudio_stream_set_loop(_ogg_stream, true) && _ogg_stream.loop, "OGG native loop enabled");
	caudio_stream_pump(_ogg_stream, 3, 1);
	caudio_free(_ogg_stream);
	_test_check(_ogg_stream.audioID == -1 && _ogg_stream.playId == -1 && !_ogg_stream.playable && _ogg_stream.done, "OGG stream released");
	_test_check(!caudio_stream_is_playable(_ogg_stream), "released OGG stream is not playable");
	caudio_free(_ogg_stream);
};

_test_case = "queue generation ownership";
var _ownership_stream = caudio_create_stream("./caudio_wav_pcm24.wav");
if (_test_check(is_struct(_ownership_stream), "create ownership test stream")) {
	caudio_stream_prime(_ownership_stream, 1);
	var _ownership_play = caudio_play(_ownership_stream, 0, false);
	_test_check(_ownership_play >= 0, "ownership test playback started");
	var _old_queue = _ownership_stream.audioQueue;
	var _old_buffer = _ownership_stream.queueBuffers[0];
	var _old_generation = _ownership_stream.queueGeneration;
	var _ownership_seek = caudio_stream_seek(_ownership_stream, 0);
	_test_check(_ownership_seek >= 0 && _ownership_stream.queueGeneration == _old_generation + 1, "seek advances queue generation");
	_test_check(_ownership_stream.audioQueue != _old_queue, "replacement queue has distinct ownership");
	var _current_buffer = _ownership_stream.queueBuffers[0];
	var _stale_current = ds_map_create();
	_stale_current[? "queue_id"] = _old_queue;
	_stale_current[? "buffer_id"] = _current_buffer;
	caudio_stream_on_async(_ownership_stream, _stale_current, 0);
	ds_map_destroy(_stale_current);
	_test_check(buffer_exists(_current_buffer) && array_get_index(_ownership_stream.queueBuffers, _current_buffer) >= 0, "old queue cannot delete current buffer");
	var _stale_old = ds_map_create();
	_stale_old[? "queue_id"] = _old_queue;
	_stale_old[? "buffer_id"] = _old_buffer;
	caudio_stream_on_async(_ownership_stream, _stale_old, 0);
	ds_map_destroy(_stale_old);
	_test_check((_old_buffer == _current_buffer) || !buffer_exists(_old_buffer), "old callback releases only its retired buffer");
	_test_check(buffer_exists(_current_buffer) && _ownership_stream.queued > 0, "current generation remains usable");
	caudio_free(_ownership_stream);
};

var _flac_helper = caudio_flac();
var _bad_source_path = "./caudio_flac_fixed_mono.flac";
var _bad_header = _flac_helper.parseHeader(_bad_source_path, true);
if (_test_check(is_struct(_bad_header), "prepare invalid FLAC fixtures")) {
	var _bad_source = _bad_header.bitReader.buffer;
	var _metadata_only_path = temp_directory + "caudio_flac_metadata_only.flac";
	buffer_save_ext(_bad_source, _metadata_only_path, 0, _bad_header.firstFrameByte);

	var _bad_channels = array_create(_bad_header.channels);
	var _bad_residuals = array_create(_bad_header.channels);
	var _bad_channel = 0;
	while (_bad_channel < _bad_header.channels) {
		_bad_channels[_bad_channel] = array_create(_bad_header.maxBlock);
		_bad_residuals[_bad_channel] = array_create(_bad_header.maxBlock);
		_bad_channel += 1;
	};
	var _first_frame = _flac_helper.decodeFrame(_bad_header.bitReader, _bad_header.streamInfo, _bad_channels, true, _bad_residuals);
	var _first_frame_end = _bad_header.bitReader.tell();
	_test_check(is_struct(_first_frame), "locate first FLAC frame boundary");

	var _truncated_path = temp_directory + "caudio_flac_truncated.flac";
	buffer_save_ext(_bad_source, _truncated_path, 0, _first_frame_end);
	var _corrupt_path = temp_directory + "caudio_flac_corrupt.flac";
	var _corrupt = buffer_create(buffer_get_size(_bad_source), buffer_fixed, 1);
	buffer_copy(_bad_source, 0, buffer_get_size(_bad_source), _corrupt, 0);
	var _corrupt_pos = _first_frame_end - 3;
	buffer_poke(_corrupt, _corrupt_pos, buffer_u8, buffer_peek(_corrupt, _corrupt_pos, buffer_u8) ^ 1);
	buffer_save(_corrupt, _corrupt_path);
	buffer_delete(_corrupt);
	_bad_header.bitReader.destroy();

	var _rollback_stream = caudio_create_stream(_corrupt_path);
	if (_test_check(is_struct(_rollback_stream), "create FLAC seek rollback stream")) {
		var _rollback_byte = _rollback_stream.bitReader.tell();
		var _rollback_bit = _rollback_stream.bitReader.bitPos;
		var _rollback_queue = _rollback_stream.audioQueue;
		var _rollback_decoded = _rollback_stream.decodedSamples;
		var _rollback_seek = caudio_stream_seek(_rollback_stream, 0.01);
		_test_check(_rollback_seek == -1, "corrupt FLAC seek fails");
		_test_check(_rollback_stream.bitReader.tell() == _rollback_byte && _rollback_stream.bitReader.bitPos == _rollback_bit, "failed seek restores reader position");
		_test_check(_rollback_stream.audioQueue == _rollback_queue && _rollback_stream.decodedSamples == _rollback_decoded, "failed seek preserves live queue state");
		caudio_free(_rollback_stream);
	};

	var _invalid_flacs = [_metadata_only_path, _truncated_path, _corrupt_path];
	var _invalid_flac_index = 0;
	while (_invalid_flac_index < array_length(_invalid_flacs)) {
		_test_case = _invalid_flacs[_invalid_flac_index];
		_test_check(caudio_create_sound(_test_case) == -1, "buffer sound rejects invalid FLAC");
		var _invalid_stream = caudio_create_stream(_test_case);
		if (is_struct(_invalid_stream)) {
			while (caudio_stream_fill(_invalid_stream)) {};
			_test_check(_invalid_stream.failed, "stream rejects invalid FLAC while decoding");
			caudio_free(_invalid_stream);
		} else {
			_test_check(true, "stream rejects invalid FLAC at creation");
		};
		_invalid_flac_index += 1;
	};
};

_test_case = "FLAC negative QLP shift";
var _lpc_out = array_create(3);
var _lpc_ok = caudio_flac().restoreLpc(1, 3, [1], -1, [2, 1, 1], _lpc_out);
_test_check(_lpc_ok && _lpc_out[0] == 2 && _lpc_out[1] == 5 && _lpc_out[2] == 11, "left-shifted LPC prediction");

_test_case = "FLAC Rice unary reader";
var _unary_buffer = buffer_create(3, buffer_fixed, 1);
buffer_poke(_unary_buffer, 0, buffer_u8, 0x00);
buffer_poke(_unary_buffer, 1, buffer_u8, 0x10);
buffer_poke(_unary_buffer, 2, buffer_u8, 0x80);
var _unary_reader = new CAudioBitReader(_unary_buffer);
_unary_reader.bitPos = 3;
_test_check(_unary_reader.readUnaryZeroes() == 8, "cross-byte zero run");
_test_check(_unary_reader.readUnaryZeroes() == 4, "continues after terminator");
_unary_reader.destroy();

show_debug_message("[CAudioTest] BEGIN deterministic stream lifecycle test");
