draw_clear(make_colour_rgb(18, 13, 29));
draw_set_colour(make_colour_rgb(205, 151, 255));
draw_text(48, 48, "CAudio streaming example");

draw_set_colour(c_white);
draw_text(48, 92, "边境之城的童谣.flac");
draw_text(48, 126, "caudio_create_stream decodes bounded chunks while the queue is playing.");

var _position = 0;
var _duration = 0;
var _queued = 0;
var _state = "open failed";
if (is_struct(stream)) {
	_position = caudio_stream_get_position(stream);
	_duration = stream.header.duration;
	_queued = stream.queued;
	if (audio_exists(stream.playId)) {
		_state = audio_is_paused(stream.playId) ? "paused" : (audio_is_playing(stream.playId) ? "playing" : "buffering");
	} else {
		_state = "buffering";
	};
};

draw_text(48, 184, $"State: { _state }    Loop: { loop }    Queued buffers: { _queued }");
draw_text(48, 216, $"Position: { string_format(_position, 0, 3) } / { string_format(_duration, 0, 3) } seconds");
draw_text(48, 280, "Space pause/resume    R restart    Left/Right seek 10s    L loop");
draw_text(48, 312, "Tab full-load example    Esc quit");
if (error_text != "") {
	draw_set_colour(c_red);
	draw_text(48, 370, error_text);
};
