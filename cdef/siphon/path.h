typedef enum {
	SP_PATH_TRAIL_SLASH = 1 << 0,  // keep trailing slash
	SP_PATH_ALLOW_EMPTY = 1 << 1,  // allow empty paths instead of '.'

	SP_PATH_URI = SP_PATH_TRAIL_SLASH | SP_PATH_ALLOW_EMPTY
} SpPathMode;

static const int SP_PATH_MAX = 4096;

void
sp_path_pop (const char *path, SpRange16 *rng, int n);

void
sp_path_split (SpRange16 *a, SpRange16 *b, const char *path, uint16_t plen, int n);

void
sp_path_splitext (SpRange16 *a, SpRange16 *b, const char *path, uint16_t plen);

int
sp_path_join (char *out, size_t len,
		const char *a, uint16_t alen,
		const char *b, uint16_t blen,
		SpPathMode mode);

uint16_t
sp_path_clean (char *path, uint16_t len, SpPathMode mode);

bool
sp_path_match (const char *path, const char *match);

int
sp_path_proc (char *buf, size_t buflen);

int
sp_path_env (const char *name, char *buf, size_t buflen);
