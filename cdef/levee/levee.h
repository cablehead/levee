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
levee_pop (Levee *self);

extern const char *
levee_get_error (Levee *self);
