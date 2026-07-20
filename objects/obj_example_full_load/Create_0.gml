audio = caudio_create_sound("./IF = Infinity.wav");
play_id = -1;
loop = false;
error_text = "";

if (is_struct(audio)) {
	play_id = caudio_play(audio, 0, loop);
} else {
	error_text = "Could not load IF = Infinity.wav";
};
