stream = caudio_create_stream("./边境之城的童谣.flac");
play_id = -1;
loop = false;
queue_target = 3;
error_text = "";

if (is_struct(stream)) {
	caudio_stream_prime(stream, queue_target);
	play_id = caudio_play(stream, 0, loop);
} else {
	error_text = "Could not open 边境之城的童谣.flac";
};
