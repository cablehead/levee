
typedef enum {
	SP_LINE_NONE  = -1,
	SP_LINE_VALUE = 1
} SpLineType;

typedef struct {
	SpLineType type; // type of the captured value
	unsigned cs;     // current scanner state
	size_t off;      // internal offset mark
} SpLine;

void
sp_line_init (SpLine *p);

ssize_t
sp_line_next (SpLine *p, const void *restrict buf, size_t len, bool eof);
