struct LeveeDialerState {
	int rc;
	int io[2];
};


struct LeveeDialerRequest {
	uint16_t node_len;
	uint16_t service_len;
	uint16_t family;
	uint16_t socktype;
	uint8_t is_listening;
	int no;
};


extern struct LeveeDialerState
levee_dialer_init ();
