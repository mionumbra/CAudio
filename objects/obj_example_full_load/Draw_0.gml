draw_clear(make_colour_rgb(13, 18, 28));
draw_set_colour(make_colour_rgb(113, 221, 183));
draw_text(48, 48, "CAudio full-load example");

draw_set_colour(c_white);
draw_text(48, 92, "IF = Infinity.wav");
draw_text(48, 126, "caudio_create_sound loads and decodes the complete file before playback.");

var _position = 0;
var _duration = 0;
var _state = "load failed";
if (is_struct(audio)) {
	_duration = audio.header.duration;
	if (audio_exists(play_id)) {
		_position = audio_sound_get_track_position(play_id);
		_state = audio_is_paused(play_id) ? "paused" : (audio_is_playing(play_id) ? "playing" : "stopped");
	} else {
		_state = "stopped";
	};
};

draw_text(48, 184, $"State: { _state }    Loop: { loop }");
draw_text(48, 216, $"Position: { string_format(_position, 0, 3) } / { string_format(_duration, 0, 3) } seconds");
draw_text(48, 280, "Space pause/resume    R restart    Left/Right seek 10s    L loop");
draw_text(48, 312, "Tab streaming example    Esc quit");
if (error_text != "") {
	draw_set_colour(c_red);
	draw_text(48, 370, error_text);
};
