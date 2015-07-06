typedef enum {
	SP_JSON_NONE       = -1,
	SP_JSON_OBJECT     = '{',
	SP_JSON_OBJECT_END = '}',
	SP_JSON_ARRAY      = '[',
	SP_JSON_ARRAY_END  = ']',
	SP_JSON_STRING     = '"',
	SP_JSON_NUMBER     = '#',
	SP_JSON_TRUE       = 't',
	SP_JSON_FALSE      = 'f',
	SP_JSON_NULL       = 'n'
} SpJsonType;


typedef struct {
	SpUtf8 utf8;        // stores the unescaped string
	double number;      // parsed number value
	SpJsonType type;    // type of the captured value
	unsigned cs;        // current scanner state
	size_t off;         // internal offset mark
	size_t mark;        // mark position for scanning doubles
	uint16_t depth;     // stack entry size
	uint8_t stack[64];  // object/array bit stack
} SpJson;


void sp_json_init (SpJson *p);
void sp_json_reset (SpJson *p);
ssize_t
	sp_json_next (SpJson *p, const void *restrict buf, size_t len, bool eof);
bool sp_json_is_done (const SpJson *p);
