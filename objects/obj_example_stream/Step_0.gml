if (keyboard_check_pressed(vk_escape)) then game_end();
if (keyboard_check_pressed(vk_tab)) then room_goto(rm_example_full_load);

if (is_struct(stream)) {
	caudio_stream_pump(stream, queue_target, 1);

	if (keyboard_check_pressed(ord("L"))) {
		loop = !loop;
		caudio_stream_set_loop(stream, loop);
	};

	if (keyboard_check_pressed(vk_space) && audio_exists(stream.playId)) {
		if (audio_is_paused(stream.playId)) then audio_resume_sound(stream.playId);
		else audio_pause_sound(stream.playId);
	};

	if (keyboard_check_pressed(ord("R"))) then caudio_stream_seek(stream, 0);
	if (keyboard_check_pressed(vk_left)) then caudio_stream_seek(stream, max(0, caudio_stream_get_position(stream) - 10));
	if (keyboard_check_pressed(vk_right)) then caudio_stream_seek(stream, min(stream.header.duration, caudio_stream_get_position(stream) + 10));
	play_id = stream.playId;
};
