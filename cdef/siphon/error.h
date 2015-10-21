static const int SP_ESYSTEM    = -1;
static const int SP_ESTATE     = -2;
static const int SP_ESYNTAX    = -3;
static const int SP_ESIZE      = -4;
static const int SP_ESTACK     = -5;
static const int SP_EESCAPE    = -6;
static const int SP_ECODEPOINT = -7;
static const int SP_EENCODING  = -8;
static const int SP_ESURROGATE = -9;
static const int SP_ETOOSHORT  = -10;


typedef struct {
	int code;
	char _domain[10], _name[20];
	char _msg[1]; /* expanded when allocated */
} SpError;


const char *
sp_strerror (int code);

int
sp_eai_code (int err);

void
sp_error_print (int code, int *out);

void
sp_exit (int code, int exitcode);

void
sp_abort (int code);

const SpError *
sp_error (int code);

const SpError *
sp_error_next (const SpError *err);

const SpError *
sp_error_add (int code, const char *domain, const char *name, const char *msg);
