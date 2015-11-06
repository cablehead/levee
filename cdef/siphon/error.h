typedef struct {
	int code;
	char _domain[10], _name[20];
	char _msg[1]; /* expanded when allocated */
} SpError;

const char *
sp_strerror (int code);

int
sp_eai_code (int err);

size_t
sp_error_string (int code, char *buf, size_t size);

void
sp_exit (int code, int exitcode);

void
sp_abort (int code);

void
sp_fabort (const char *fmt, ...);

const SpError *
sp_error (int code);

const SpError *
sp_error_next (const SpError *err);

const SpError *
sp_error_add (int code, const char *domain, const char *name, const char *msg);
