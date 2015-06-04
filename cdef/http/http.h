typedef struct {
	uint8_t method_off;
	uint8_t method_len;
	uint16_t uri_off;
	uint16_t uri_len;
	uint8_t version;
} HTTPRequestLine;

typedef struct {
	uint16_t reason_off;
	uint16_t reason_len;
	uint16_t status;
	uint8_t version;
} HTTPResponseLine;

typedef struct {
	uint16_t name_off;
	uint16_t name_len;
	uint16_t value_off;
	uint16_t value_len;
} HTTPField;

typedef struct {
	size_t content_length;
	bool chunked;
} HTTPBodyStart;

typedef struct {
	size_t length;
} HTTPBodyChunk;

typedef enum {
	HTTP_PARSER_NONE = -1,
	HTTP_PARSER_REQUEST,       // complete request line
	HTTP_PARSER_RESPONSE,      // complete response line
	HTTP_PARSER_FIELD,         // header or trailer field name and value
	HTTP_PARSER_BODY_START,    // start of the body
	HTTP_PARSER_BODY_CHUNK,    // size for chunked body
	HTTP_PARSER_BODY_END,      // end of the body chunks
	HTTP_PARSER_TRAILER_END    // complete request or response
} HTTPType;

typedef struct {
	// readonly
	union {
		HTTPRequestLine  request;    // request line values
		HTTPResponseLine response;   // response line values
		HTTPField        field;      // header field name and value
		HTTPBodyStart    body_start; // beginning of body
		HTTPBodyChunk    body_chunk; // size of next chunk
	} as;                // captured value
	HTTPType type;       // type of the captured value
	unsigned cs;         // current scanner state
	size_t off;          // internal offset mark
	size_t body_len;     // content length or current chunk size
	uint16_t scans;      // number of passes through the scanner
	bool response;       // true if response, false if request
	bool chunked;        // set by field scanner
	bool trailers;       // parsing trailers
} HTTPParser;

extern void
http_parser_init_request (HTTPParser *p);

extern void
http_parser_init_response (HTTPParser *p);

extern void
http_parser_reset (HTTPParser *p);

extern ssize_t
http_parser_next (HTTPParser *p, const void *restrict buf, size_t len);

extern bool
http_parser_is_done (const HTTPParser *p);

