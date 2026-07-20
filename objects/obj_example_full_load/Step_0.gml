if (keyboard_check_pressed(vk_escape)) then game_end();
if (keyboard_check_pressed(vk_tab)) then room_goto(rm_example_stream);

if (is_struct(audio)) {
	if (keyboard_check_pressed(ord("L"))) {
		loop = !loop;
		if (audio_exists(play_id)) then audio_sound_loop(play_id, loop);
	};

	if (keyboard_check_pressed(vk_space) && audio_exists(play_id)) {
		if (audio_is_paused(play_id)) then audio_resume_sound(play_id);
		else audio_pause_sound(play_id);
	};

	if (keyboard_check_pressed(ord("R"))) {
		if (audio_exists(play_id)) then audio_stop_sound(play_id);
		play_id = caudio_play(audio, 0, loop);
	};

	if (audio_exists(play_id)) {
		var _position = audio_sound_get_track_position(play_id);
		if (keyboard_check_pressed(vk_left)) then audio_sound_set_track_position(play_id, max(0, _position - 10));
		if (keyboard_check_pressed(vk_right)) then audio_sound_set_track_position(play_id, min(audio.header.duration, _position + 10));
	};
};
