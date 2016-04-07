typedef struct Levee Levee;

extern Levee *
levee_create (void);

extern void
levee_destroy (Levee *self);

extern bool
levee_load_file (Levee *self, const char *path);

extern bool
levee_load_string (Levee *self, const char *script, size_t len, const char *name);

extern bool
levee_run (Levee *self, int nargs, bool bg);

extern void
levee_push_number (Levee *self, double num);

extern void
levee_push_string (Levee *self, const char *str, size_t len);

extern void
levee_push_bool (Levee *self, bool val);

extern void
levee_push_nil (Levee *self);

extern void
levee_push_sender (Levee *self, LeveeChanSender *sender);

extern void
levee_pop (Levee *self, int n);

extern void
levee_print_stack (Levee *self, const char *msg);

extern const char *
levee_get_error (Levee *self);

extern size_t
levee_getcurrentrss ();

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


struct LeveeDialerResponse {
	int err;
	int eai;
	int no;
};

extern const struct LeveeDialerState
levee_dialer_init ();
