if ((async_load[? "queue_id"]) == _) {
	buffer_delete(async_load[? "buffer_id"]);
	if ((-- _queue_status) < _queue_minnum) {
		event_user(1);
		_queue_status = _queue_minnum;
	};
};
