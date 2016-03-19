typedef struct {
	uint8_t *buf;
    size_t len;
    size_t cap;
	bool fixed;
} SpUtf8;

typedef enum {
	SP_UTF8_NONE          = 0,      // no encoding
	SP_UTF8_JSON          = 1 << 0, // json string scheme
	SP_UTF8_URI           = 1 << 1, // percent scheme
	SP_UTF8_URI_COMPONENT = 1 << 2, // percent scheme for uri components
	SP_UTF8_SPACE_PLUS    = 1 << 3, // treat plus as a space character
} SpUtf8Flags;

void
sp_utf8_init (SpUtf8 *u);

void
sp_utf8_init_fixed (SpUtf8 *u, void *buf, size_t len);

void
sp_utf8_final (SpUtf8 *u);

ssize_t
sp_utf8_encode (SpUtf8 *u, const void *src, size_t len, SpUtf8Flags f);

ssize_t
sp_utf8_decode (SpUtf8 *u, const void *src, size_t len, SpUtf8Flags f);

ssize_t
sp_utf8_charlen (const void *src, size_t len);
