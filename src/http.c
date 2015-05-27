#include "http.h"

#include <stdio.h>
#include <assert.h>
#include <ctype.h>
#include <string.h>

#include "pcmp/eq16.h"
#include "pcmp/leq.h"
#include "pcmp/leq16.h"
#include "pcmp/set16.h"
#include "pcmp/range16.h"



// TODO: add support for strings and lws within header field values



#define LEQ(cmp, off, len) \
	(len == sizeof cmp - 1 && pcmp_leq (off, (uint8_t *)cmp, sizeof cmp - 1))

#define LEQ16(cmp, off, len) \
	(len == sizeof cmp - 1 && pcmp_leq16 (off, (uint8_t *)cmp, sizeof cmp - 1))



#define YIELD_ERROR(err) do { \
	p->cs = DONE;             \
	return err;               \
} while (0)

#define YIELD(typ, next) do { \
	p->cs = next;             \
	p->off = 0;               \
	p->type = typ;            \
	return end - m;           \
} while (0)



#define EXPECT_MAX_OFFSET(max) do {                                 \
	if (pcmp_unlikely (p->off > (size_t)max)) {                     \
		YIELD_ERROR (HTTP_PARSER_ESIZE);                            \
	}                                                               \
} while (0)

#define EXPECT_RANGE_THEN_CHAR(rng, ch, max) do {                   \
	end = pcmp_range16 (m+p->off, len-p->off, rng, sizeof rng - 1); \
	if (end == NULL) {                                              \
		p->off = len;                                               \
		EXPECT_MAX_OFFSET (max);                                    \
		return 0;                                                   \
	}                                                               \
	if (pcmp_unlikely (*end != ch)) {                               \
		YIELD_ERROR (HTTP_PARSER_EPROTO);                           \
	}                                                               \
	end++;                                                          \
	p->off = end - m;                                               \
	EXPECT_MAX_OFFSET (max+1);                                      \
} while (0)

#define EXPECT_RANGE(rng, max) do {                                 \
	end = pcmp_range16 (m+p->off, len-p->off, rng, sizeof rng - 1); \
	if (end == NULL) {                                              \
		p->off = len;                                               \
		EXPECT_MAX_OFFSET (max);                                    \
		return 0;                                                   \
	}                                                               \
	p->off = end - m;                                               \
	EXPECT_MAX_OFFSET (max);                                        \
} while (0)

#define EXPECT_CHAR(ch) do {                                        \
	if (len == p->off) return 0;                                    \
	if (pcmp_unlikely (m[p->off] != ch)) {                          \
		YIELD_ERROR (HTTP_PARSER_EPROTO);                           \
	}                                                               \
	end++;                                                          \
	p->off++;                                                       \
} while (0)

#define EXPECT_PREFIX(pre, extra) do {                              \
	if (len-p->off < sizeof pre - 1 + extra) {                      \
		return 0;                                                   \
	}                                                               \
	if (!pcmp_eq16 (m+p->off, pre, sizeof pre - 1)) {               \
		YIELD_ERROR (HTTP_PARSER_EPROTO);                           \
	}                                                               \
	end = m + p->off + sizeof pre - 1;                              \
	p->off += (sizeof pre - 1) + extra;                             \
} while (0)

#define EXPECT_EOL(max) do {                                        \
	end = pcmp_set16 (m+p->off, len-p->off, crlf, 1);               \
	if (end == NULL) {                                              \
		p->off = len;                                               \
		EXPECT_MAX_OFFSET (max);                                    \
		return 0;                                                   \
	}                                                               \
	if (pcmp_unlikely ((size_t)(end - m) == len - 1)) {             \
		p->off = len - 1;                                           \
		return 0;                                                   \
	}                                                               \
	if (pcmp_unlikely (end[1] != crlf[1])) {                        \
		YIELD_ERROR (HTTP_PARSER_EPROTO);                           \
	}                                                               \
	end += 2;                                                       \
	p->off = end - m;                                               \
	EXPECT_MAX_OFFSET (max+2);                                      \
} while (0)



static const uint8_t crlf[] = "\r\n";
static const uint8_t version_start[] = "HTTP/1.";



#define REQ       0x00000F
#define REQ_METH  0x000001
#define REQ_URI   0x000002
#define REQ_VER   0x000003
#define REQ_EOL   0x000004

#define RES       0x0000F0
#define RES_VER   0x000010
#define RES_SEP   0x000020
#define RES_CODE  0x000030
#define RES_MSG   0x000040

#define FLD       0x000F00
#define FLD_KEY   0x000100
#define FLD_LWS   0x000200
#define FLD_VAL   0x000300

#define CHUNK     0x00F000
#define CHUNK_NUM 0x001000
#define CHUNK_EOL 0x002000

#define DONE      0xF00000

static int
scrape_field (HTTPParser *restrict p, const uint8_t *restrict m)
{
	if (p->trailers || p->body_len) {
		return 0;
	}

	if (LEQ16 ("content-length", m + p->as.field.name_off, p->as.field.name_len)) {
		if (p->as.field.value_len == 0) {
			YIELD_ERROR (HTTP_PARSER_EPROTO);
		}
		size_t num = 0;
		const uint8_t *s = m + p->as.field.value_off;
		const uint8_t *e = s + p->as.field.value_len;
		while (s < e) {
			if (!isdigit (*s)) {
				YIELD_ERROR (HTTP_PARSER_EPROTO);
			}
			num = num * 10 + (*s - '0');
			s++;
		}
		p->body_len = num;
		return 0;
	}

	if (LEQ ("transfer-encoding", m + p->as.field.name_off, p->as.field.name_len) &&
			LEQ16 ("chunked", m + p->as.field.value_off, p->as.field.value_len)) {
		p->chunked = true;
		return 0;
	}

	return 0;
}

static ssize_t
parse_request_line (HTTPParser *restrict p, const uint8_t *restrict m, size_t len)
{
	static const uint8_t method_sep[] = "\0@[`{\xff"; // must match ' '
	static const uint8_t uri_sep[] = "\0 \x7f\xff"; // must match ' '

	p->type = HTTP_PARSER_NONE;

	const uint8_t *end;

	switch (p->cs) {
	case REQ:
		p->cs = REQ_METH;
		p->as.request.method_off = (uint8_t)p->off;

	case REQ_METH:
		EXPECT_RANGE_THEN_CHAR (method_sep, ' ', HTTP_PARSER_MAX_METHOD);
		p->as.request.method_len = (uint8_t)(p->off - 1);
		p->cs = REQ_URI;
		p->as.request.uri_off = p->off;

	case REQ_URI:
		EXPECT_RANGE_THEN_CHAR (uri_sep, ' ', HTTP_PARSER_MAX_URI);
		p->as.request.uri_len = (uint16_t)(p->off - 1 - p->as.request.uri_off);
		p->cs = REQ_VER;

	case REQ_VER:
		EXPECT_PREFIX (version_start, 1);
		if (!isdigit (*end)) {
			YIELD_ERROR (HTTP_PARSER_EPROTO);
		}
		p->as.request.version = (uint8_t)(*end - '0');
		p->cs = REQ_EOL;

	case REQ_EOL:
		EXPECT_PREFIX (crlf, 0);
		YIELD (HTTP_PARSER_REQUEST, FLD);

	default:
		YIELD_ERROR (HTTP_PARSER_ESTATE);
	}
}

static ssize_t
parse_response_line (HTTPParser *restrict p, const uint8_t *restrict m, size_t len)
{
	p->type = HTTP_PARSER_NONE;

	const uint8_t *end;

	switch (p->cs) {
	case RES:
		p->cs = RES_VER;

	case RES_VER:
		EXPECT_PREFIX (version_start, 1);
		if (!isdigit (*end)) {
			YIELD_ERROR (HTTP_PARSER_EPROTO);
		}
		p->as.response.version = (uint8_t)(*end - '0');
		p->cs = RES_SEP;
	
	case RES_SEP:
		EXPECT_CHAR (' ');
		p->cs = RES_CODE;
		p->as.response.status = 0;

	case RES_CODE:
		do {
			if (p->off == len) return 0;
			uint8_t c = m[p->off];
			if (c == ' ') {
				p->off++;
				break;
			}
			if (isdigit (c)) {
				p->as.response.status = p->as.response.status * 10 + (c - '0');
				p->off++;
			}
			else {
				YIELD_ERROR (HTTP_PARSER_EPROTO);
			}
		} while (true);
		p->as.response.reason_off = p->off;
		p->cs = RES_MSG;

	case RES_MSG:
		EXPECT_EOL (HTTP_PARSER_MAX_REASON + p->as.response.reason_off);
		p->as.response.reason_len = (uint16_t)(p->off - p->as.response.reason_off - (sizeof crlf - 1));
		YIELD (HTTP_PARSER_RESPONSE, FLD);

	default:
		YIELD_ERROR (HTTP_PARSER_ESTATE);
	}
}

static ssize_t
parse_field (HTTPParser *restrict p, const uint8_t *restrict m, size_t len)
{
	static const uint8_t field_sep[] = ":@\0 \"\"()[]//{{}}"; // must match ':', allows commas
	static const uint8_t field_lws[] = "\0\x08\x0A\x1f!\xff";

	p->type = HTTP_PARSER_NONE;

	const uint8_t *end;

	switch (p->cs) {
	case FLD:
		if (len < sizeof crlf - 1) {
			return 0;
		}
		if (m[0] == crlf[0] && m[1] == crlf[1]) {
			end = m + 2;
			p->as.body_start.chunked = p->chunked;
			p->as.body_start.content_length = p->body_len;
			if (p->trailers) {
				YIELD (HTTP_PARSER_TRAILER_END, DONE);
			}
			else {
				YIELD (HTTP_PARSER_BODY_START, p->chunked ? CHUNK : DONE);
			}
		}
		p->cs = FLD_KEY;
		p->as.field.name_off = 0;

	case FLD_KEY:
		EXPECT_RANGE_THEN_CHAR (field_sep, ':', HTTP_PARSER_MAX_FIELD);
		p->as.field.name_len = (uint16_t)(p->off - 1);
		p->cs = FLD_LWS;

	case FLD_LWS:
		EXPECT_RANGE (field_lws, HTTP_PARSER_MAX_VALUE + p->as.field.value_off);
		p->as.field.value_off = (uint16_t)p->off;
		p->cs = FLD_VAL;

	case FLD_VAL:
		EXPECT_EOL (HTTP_PARSER_MAX_VALUE + p->as.field.value_off);
		p->as.field.value_len = (uint16_t)(p->off - p->as.field.value_off - (sizeof crlf - 1));
		if (!p->trailers) {
			scrape_field (p, m);
		}
		YIELD (HTTP_PARSER_FIELD, FLD);

	default:
		YIELD_ERROR (HTTP_PARSER_ESTATE);
	}
}

static ssize_t
parse_chunk (HTTPParser *restrict p, const uint8_t *restrict m, size_t len)
{
	static const uint8_t hex[] = {
		['0'] = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
		['A'] = 10, 11, 12, 13, 14, 15,
		['a'] = 10, 11, 12, 13, 14, 15
	};

	p->type = HTTP_PARSER_NONE;

	const uint8_t *end;

	switch (p->cs) {
	case CHUNK:
		p->off = 0;
		p->body_len = 0;
		p->cs = CHUNK_NUM;
	
	case CHUNK_NUM:
		do {
			if (p->off == len) return 0;
			uint8_t c = m[p->off];
			if (isxdigit (c)) {
				p->body_len = (p->body_len << 4) | hex[c];
				p->off++;
			}
			else {
				break;
			}
		} while (true);
		p->cs = CHUNK_EOL;
	
	case CHUNK_EOL:
		EXPECT_PREFIX (crlf, 0);
		p->off += 2;
		if (p->body_len == 0) {
			p->trailers = true;
			YIELD (HTTP_PARSER_BODY_END, FLD);
		}
		else {
			p->as.body_chunk.length = p->body_len;
			p->body_len = 0;
			YIELD (HTTP_PARSER_BODY_CHUNK, CHUNK);
		}

	default:
		YIELD_ERROR (HTTP_PARSER_ESTATE);
	}
}

void
http_parser_init_request (HTTPParser *p)
{
	memset (p, 0, sizeof *p);
	p->cs = REQ;
}

void
http_parser_init_response (HTTPParser *p)
{
	memset (p, 0, sizeof *p);
	p->cs = RES;
	p->response = true;
}

ssize_t
http_parser_next (HTTPParser *p, const void *restrict buf, size_t len)
{
	p->scans++;
	if (p->cs & REQ)   return parse_request_line (p, buf, len);
	if (p->cs & RES)   return parse_response_line (p, buf, len);
	if (p->cs & FLD)   return parse_field (p, buf, len);
	if (p->cs & CHUNK) return parse_chunk (p, buf, len);
	YIELD_ERROR (HTTP_PARSER_ESTATE);
}

bool
http_parser_is_done (const HTTPParser *p)
{
	assert (p != NULL);

	return p->cs == DONE;
}

