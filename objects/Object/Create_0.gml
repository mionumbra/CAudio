_path = "./IF = Infinity.wav";

_audio = (caudio_create_sound_wav(_path)); _ = (_audio.audioID);

//
/*
_audio = (caudio_create_sound_stream(_path)); _ = (_audio.audioQueue); var _header = (_audio.header);
_chunk_size = ((_header.sampleRate) * ((_header.bits) / 8) * (_header.channels) * 0.1);
_queue_minnum = 3; _queue_status = _queue_minnum; show_debug_message(_chunk_size);
_data_size = (_header.dataSize); _data_offset = (_header.dataOffset);
repeat(_queue_minnum) event_user(1);
*/

//
show_debug_message(_audio);
_ins = (audio_play_sound(_, 0, false));
