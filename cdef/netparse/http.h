typedef union {
	// request line values
	struct {
		uint8_t method_off;
		uint8_t method_len;
		uint16_t uri_off;
		uint16_t uri_len;
		uint8_t version;
	} request;

	// response line values
	struct {
		uint16_t reason_off;
		uint16_t reason_len;
		uint16_t status;
		uint8_t version;
	} response;

	// header field name and value
	struct {
		uint16_t name_off;
		uint16_t name_len;
		uint16_t value_off;
		uint16_t value_len;
	} field;

	// beginning of body
	struct {
		size_t content_length;
		bool chunked;
	} body_start;

	// size of next chunk
	struct {
		size_t length;
	} body_chunk;
} NpHttpValue;

typedef enum {
	NP_HTTP_NONE = -1,
	NP_HTTP_REQUEST,     // complete request line
	NP_HTTP_RESPONSE,    // complete response line
	NP_HTTP_FIELD,       // header or trailer field name and value
	NP_HTTP_BODY_START,  // start of the body
	NP_HTTP_BODY_CHUNK,  // size for chunked body
	NP_HTTP_BODY_END,    // end of the body chunks
	NP_HTTP_TRAILER_END  // complete request or response
} NpHttpType;

typedef struct {
	NpHttpValue as;   // captured value
	NpHttpType type;  // type of the captured value
	unsigned cs;      // current scanner state
	size_t off;       // internal offset mark
	size_t body_len;  // content length or current chunk size
	uint16_t scans;   // number of passes through the scanner
	bool response;    // true if response, false if request
	bool chunked;     // set by field scanner
	bool trailers;    // parsing trailers
} NpHttp;

extern void
np_http_init_request (NpHttp *p);

extern void
np_http_init_response (NpHttp *p);

extern void
np_http_reset (NpHttp *p);

extern ssize_t
np_http_next (NpHttp *p, const void *restrict buf, size_t len);

extern bool
np_http_is_done (const NpHttp *p);

