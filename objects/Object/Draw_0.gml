var _pos = 0, _len = 0, _q = 0, _pl = 0;
if (is_struct(_audio)) {
	_len = (_audio.header.duration);
	_q = (_audio.queued);
	_pos = (caudio_stream_get_position(_audio));
	_pl = (audio_is_playing(_audio.playId) ? 1 : 0);
};
draw_text(0, 0, $"{ _pos }/{ _len } q={ _q } play={ _pl }  [←/→ seek, L loop]");