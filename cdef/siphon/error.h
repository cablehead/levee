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

const char *sp_strerror (int code);
