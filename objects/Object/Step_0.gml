var _elapsed_ms = 0;
var _expected_kind = "";
var _primed = 0;
var _seek_target = 0;
var _seek_result = -1;
var _started = 0;

_test_frames += 1;

if (_test_frames > 180) {
	_test_check(false, $"phase { _test_phase } completed before timeout");
	_test_phase = 4;
};

switch (_test_phase) {
	case 0:
		_test_index += 1;
		if (_test_index >= array_length(_test_paths)) {
			if (!_stress_started) {
				_stress_started = true;
				_test_phase = 6;
				_test_frames = 0;
				break;
			};
			if (!_position_started) {
				_position_started = true;
				_test_phase = 11;
				_test_frames = 0;
				break;
			};
			if (_test_failures == 0) {
				show_debug_message("[CAudioTest] RESULT PASS failures=0");
			} else {
				show_debug_message($"[CAudioTest] RESULT FAIL failures={ _test_failures }");
			};
			game_end();
			exit;
		};

		_test_case = _test_paths[_test_index];
		_expected_kind = _test_kinds[_test_index];
		_audio = undefined;
		_started = get_timer();
		_audio = caudio_create_stream(_test_case);
		_elapsed_ms = (get_timer() - _started) / 1000;
		if (!_test_check(is_struct(_audio), $"create stream ({ _elapsed_ms }ms)")) {
			_test_phase = 4;
			_test_frames = 0;
			break;
		};

		_test_check(_audio.kind == _expected_kind, $"dispatch kind={ _expected_kind }");
		_test_check(_audio.mode == "stream", "stream mode handle");
		_test_check(_audio.audioQueue >= 0, "play queue created");
		caudio_stream_set_loop(_audio, false);
		_primed = caudio_stream_prime(_audio, _queue_min);
		_test_check((_primed > 0) && (_audio.queued >= _queue_min), $"prime queued={ _audio.queued }");
		_ins = caudio_play(_audio, 0, false);
		_test_check(_ins >= 0, "play started");
		_test_phase = 1;
		_test_frames = 0;
		break;

	case 6:
		_test_case = "FLAC repeated seek lifecycle";
		_audio = caudio_create_stream("./test.flac");
		if (!_test_check(is_struct(_audio), "create stress stream")) {
			_test_phase = 9;
			_test_frames = 0;
			break;
		};
		caudio_stream_prime(_audio, 2);
		_ins = caudio_play(_audio, 0, false);
		_test_check(_ins >= 0, "stress playback started");
		_stress_seeks = 0;
		_test_phase = 7;
		_test_frames = 0;
		break;

	case 7:
		var _stress_target = ((_stress_seeks mod 2) == 0) ? 0.125 : 0.375;
		_seek_result = caudio_stream_seek(_audio, _stress_target);
		_test_check(abs(_seek_result - _stress_target) <= (1 / _audio.header.sampleRate), $"stress seek { _stress_seeks }");
		_test_check((_audio.queued > 0) && (_audio.audioQueue >= 0) && (_audio.playId >= 0), "current queue survives old callbacks");
		_stress_seeks += 1;
		if (_stress_seeks >= 12) {
			_test_phase = 8;
			_test_frames = 0;
		};
		break;

	case 8:
		caudio_stream_pump(_audio, 2, 1);
		if (_test_frames >= 30) {
			_test_check((_audio.queued > 0) && (_audio.audioQueue >= 0), "queue remains usable after delayed callbacks");
			_test_check(array_length(_audio.queueBuffers) == _audio.queued, "queue metadata remains consistent");
			_test_check(buffer_exists(_audio.queueBuffers[0]), "current queue buffers remain valid");
			_registry_buffer = _audio.queueBuffers[0];
			_registry_pending_before = caudio_retired_queue_pending();
			caudio_free(_audio);
			_test_check(_audio.audioQueue == -1 && _audio.done, "stress stream released");
			_test_check(caudio_retired_queue_pending() > _registry_pending_before, "free transfers outstanding buffers to persistent registry");
			_audio = undefined;
			_test_phase = 10;
			_test_frames = 0;
		};
		break;

	case 10:
		if ((caudio_retired_queue_pending() == 0) || (_test_frames >= 120)) {
			_test_check(caudio_retired_queue_pending() == 0, "callbacks reclaim buffers after stream reference is discarded");
			_test_check(!buffer_exists(_registry_buffer), "discarded stream buffer is released");
			_test_phase = 0;
			_test_frames = 0;
		};
		break;

	case 11:
		_test_case = "WAV natural loop position";
		_audio = caudio_create_stream("./caudio_wav_pcm24.wav");
		if (!_test_check(is_struct(_audio), "create short loop stream")) {
			_test_phase = 14;
			break;
		};
		caudio_stream_set_loop(_audio, true);
		caudio_stream_prime(_audio, 3);
		_ins = caudio_play(_audio, 0, true);
		_position_last = caudio_stream_get_position(_audio);
		_position_wrapped = false;
		_test_phase = 12;
		_test_frames = 0;
		break;

	case 12:
		caudio_stream_pump(_audio, 3, 1);
		var _wav_position = caudio_stream_get_position(_audio);
		if (_wav_position + (1 / _audio.header.sampleRate) < _position_last) then _position_wrapped = true;
		_position_last = _wav_position;
		if (_test_frames >= 45) {
			var _wav_tolerance = (1.0 / _audio.header.sampleRate);
			_test_check((_wav_position >= 0) && (_wav_position <= _audio.header.duration + _wav_tolerance), $"position remains within one sample of duration value={ string_format(_wav_position, 0, 6) } duration={ string_format(_audio.header.duration, 0, 6) }");
			_test_check(_position_wrapped, "position wraps at a natural loop boundary");
			caudio_free(_audio);
			_test_phase = 14;
			_test_frames = 0;
		};
		break;

	case 14:
		_test_case = "FLAC short-tail loop position";
		_audio = caudio_create_stream("./caudio_flac_fixed_mono.flac");
		if (!_test_check(is_struct(_audio), "create short-tail loop stream")) {
			_test_phase = 0;
			break;
		};
		caudio_stream_set_loop(_audio, true);
		caudio_stream_prime(_audio, 3);
		_ins = caudio_play(_audio, 0, true);
		_position_last = caudio_stream_get_position(_audio);
		_position_wrapped = false;
		_test_phase = 15;
		_test_frames = 0;
		break;

	case 15:
		caudio_stream_pump(_audio, 3, 1);
		var _flac_position = caudio_stream_get_position(_audio);
		if (_flac_position + (1 / _audio.header.sampleRate) < _position_last) then _position_wrapped = true;
		_position_last = _flac_position;
		if (_test_frames >= 60) {
			var _flac_tolerance = (1.0 / _audio.header.sampleRate);
			_test_check((_flac_position >= 0) && (_flac_position <= _audio.header.duration + _flac_tolerance), $"position remains within one sample of duration value={ string_format(_flac_position, 0, 6) } duration={ string_format(_audio.header.duration, 0, 6) }");
			_test_check(_position_wrapped, "position wraps across short-tail loop buffers");
			caudio_free(_audio);
			_test_phase = 0;
			_test_frames = 0;
		};
		break;

	case 9:
		if (is_struct(_audio)) then caudio_free(_audio);
		_test_phase = 0;
		_test_frames = 0;
		break;

	case 1:
		caudio_stream_pump(_audio, _queue_min, 1);
		if (_test_frames >= 12) {
			_seek_target = min(0.25, max(0, (_audio.header.duration) * 0.25));
			_seek_result = caudio_stream_seek(_audio, _seek_target);
			_test_check(_seek_result >= 0, $"seek target={ _seek_target } result={ _seek_result }");
			_test_check(abs(_seek_result - _seek_target) <= (1 / _audio.header.sampleRate), "seek is sample-accurate");
			_test_check(abs(caudio_stream_get_position(_audio) - _seek_result) < 0.1, "position starts at seek target");
			_test_check(_audio.queued > 0, $"seek re-primed queued={ _audio.queued }");
			_test_check(_audio.playId >= 0, "seek restarted playback");
			_test_phase = 2;
			_test_frames = 0;
		};
		break;

	case 2:
		caudio_stream_pump(_audio, _queue_min, 1);
		if (_test_frames >= 12) {
			_test_check(caudio_stream_set_loop(_audio, true) && _audio.loop, "loop enabled");
			if (audio_exists(_audio.playId)) then audio_stop_sound(_audio.playId);
			_queue_min = 0;
			_test_phase = 5;
			_test_frames = 0;
		};
		break;

	case 5:
		if ((_audio.queued == 0) || (_test_frames >= 120)) {
			_test_check(_audio.queued == 0, "stop callbacks drained queue accounting");
			_queue_min = 1;
			caudio_stream_pump(_audio, _queue_min, 1);
			_test_check((_audio.queued > 0) && (_audio.playId >= 0), "pump recovered queue underrun");
			_test_phase = 3;
			_test_frames = 0;
		};
		break;

	case 3:
		caudio_stream_pump(_audio, _queue_min, 1);
		if (_test_frames >= 6) {
			_seek_result = caudio_stream_seek(_audio, 0);
			_test_check(_seek_result >= 0, "looping stream seeked to start");
			_test_check(_audio.queued > 0, "queue usable after recovery");
			_test_phase = 4;
			_test_frames = 0;
		};
		break;

	case 4:
		if (is_struct(_audio)) {
			caudio_free(_audio);
			_test_check(_audio.audioQueue == -1, "queue released");
			_test_check(_audio.done, "stream marked done");
			if (_audio.kind == "flac") {
				_test_check(is_undefined(_audio.bitReader), "FLAC reader released");
			};
			caudio_free(_audio);
		};
		_test_phase = 0;
		_test_frames = 0;
		break;
};
