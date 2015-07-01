typedef struct Levee Levee;

extern Levee *
levee_create (void);

extern void
levee_destroy (Levee *self);

extern int
levee_load_file (Levee *self, const char *path);

extern int
levee_load_string (Levee *self, const char *script, size_t len, const char *name);

extern void
levee_set_arg (Levee *self, int argc, const char **argv);

extern int
levee_run (Levee *self, bool bg);
