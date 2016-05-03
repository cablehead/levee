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
} SpHttpValue;

typedef enum {
	SP_HTTP_NONE = -1,
	SP_HTTP_REQUEST,     // complete request line
	SP_HTTP_RESPONSE,    // complete response line
	SP_HTTP_FIELD,       // header or trailer field name and value
	SP_HTTP_BODY_START,  // start of the body
	SP_HTTP_BODY_CHUNK,  // size for chunked body
	SP_HTTP_BODY_END,    // end of the body chunks
	SP_HTTP_TRAILER_END  // complete request or response
} SpHttpType;

typedef struct SpHttpMap SpHttpMap;
typedef struct SpHttpEntry SpHttpEntry;

typedef struct {
	// public
	uint16_t max_method; // max size for a request method
	uint16_t max_uri;    // max size for a request uri
	uint16_t max_reason; // max size for a response status message
	uint16_t max_field;  // max size for a header field
	uint16_t max_value;  // max size for a header value

	// readonly
	uint16_t scans;      // number of passes through the scanner
	uint8_t cscans;      // number of scans in the current rule
	bool response;       // true if response, false if request
	bool chunked;        // set by field scanner
	bool trailers;       // parsing trailers
	SpHttpValue as;      // captured value
	SpHttpType type;     // type of the captured value
	unsigned cs;         // current scanner state
	size_t off;          // internal offset mark
	size_t body_len;     // content length or current chunk size
	SpHttpMap *headers;  // map reference to capture headers
} SpHttp;

void
sp_http_init_request (SpHttp *p, bool capture);

void
sp_http_init_response (SpHttp *p, bool capture);

void
sp_http_final (SpHttp *p);

void
sp_http_reset (SpHttp *p);

ssize_t
sp_http_next (SpHttp *p, const void *restrict buf, size_t len);

bool
sp_http_is_done (const SpHttp *p);



SpHttpMap *
sp_http_map_new (void);

void
sp_http_map_free (SpHttpMap *m);

int
sp_http_map_put (SpHttpMap *m,
		const void *name, uint16_t nlen,
		const void *value, uint16_t vlen);

bool
sp_http_map_del (SpHttpMap *m, const void *name, uint16_t nlen);

void
sp_http_map_clear (SpHttpMap *m);

const SpHttpEntry *
sp_http_map_get (const SpHttpMap *m, const void *name, uint16_t nlen);

size_t
sp_http_map_encode_size (const SpHttpMap *m);

void
sp_http_map_encode (const SpHttpMap *m, void *buf);

size_t
sp_http_map_scatter_count (const SpHttpMap *m);

void
sp_http_map_scatter (const SpHttpMap *m, struct iovec *iov);

void
sp_http_entry_name (const SpHttpEntry *e, struct iovec *iov);

size_t
sp_http_entry_count (const SpHttpEntry *e);

bool
sp_http_entry_value (const SpHttpEntry *e, size_t idx, struct iovec *iov);

