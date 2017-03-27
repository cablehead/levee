typedef enum {
	SP_PATH_TRAIL_SLASH = 1 << 0,  // keep trailing slash
	SP_PATH_ALLOW_EMPTY = 1 << 1,  // allow empty paths instead of '.'

	SP_PATH_URI = SP_PATH_TRAIL_SLASH | SP_PATH_ALLOW_EMPTY
} SpPathMode;

typedef enum {
	SP_PATH_UNKNOWN = 0,
	SP_PATH_FIFO    = 1,
	SP_PATH_CHR     = 2,
	SP_PATH_DIR     = 4,
	SP_PATH_BLK     = 6,
	SP_PATH_REG     = 8,
	SP_PATH_LNK     = 10,
	SP_PATH_SOCK    = 12,
	SP_PATH_WHT     = 14,
} SpPathType;

typedef struct {
	unsigned long st_device;
	unsigned int  st_mode;
	unsigned int  st_nlink;
	unsigned int  st_uid;
	unsigned int  st_gid;
	unsigned long st_rdev;
	long          st_size;
	struct timespec st_atime;
	struct timespec st_mtime;
	struct timespec st_ctime;
} SpStat;

static const int SP_PATH_MAX = 4096;

typedef struct {
	void **stack;
	uint16_t flags, dirlen, pathlen;
	uint8_t cur, max;
	SpStat _stat;
	bool empty;
	char path[SP_PATH_MAX];
} SpDir;

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


int
sp_dir_open (SpDir *self, const char *path, uint8_t depth);

void
sp_dir_close (SpDir *self);

int
sp_dir_next (SpDir *self);

void
sp_dir_skip (SpDir *self);

int
sp_dir_follow (SpDir *self);

SpPathType
sp_dir_type (SpDir *self);

const SpStat *
sp_dir_stat (SpDir *self);

void
sp_dir_pathname (const SpDir *self, const char **start, size_t *len);

void
sp_dir_dirname (const SpDir *self, const char **start, size_t *len);

void
sp_dir_basename (const SpDir *self, const char **start, size_t *len);


int
sp_stat (const char *path, SpStat *sbuf, bool follow);

int
sp_fstat (int fd, SpStat *sbuf);
