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



// TODO: set a target scan limit rather than size checks after matching
// TODO: track m and end differently




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
	out->type = typ;          \
	return end - m;           \
} while (0)



#define EXPECT_RANGE_THEN_CHAR(rng, ch) do {                        \
	end = pcmp_range16 (m+p->off, len-p->off, rng, sizeof rng - 1); \
	if (end == NULL) {                                              \
		p->off = len;                                               \
		return 0;                                                   \
	}                                                               \
	if (pcmp_unlikely (*end != ch)) {                               \
		YIELD_ERROR (HTTP_PARSER_EPROTO);                           \
	}                                                               \
	end++;                                                          \
	p->off = end - m;                                               \
} while (0)

#define EXPECT_RANGE(rng) do {                                      \
	end = pcmp_range16 (m+p->off, len-p->off, rng, sizeof rng - 1); \
	if (end == NULL) {                                              \
		p->off = len;                                               \
		return 0;                                                   \
	}                                                               \
	p->off = end - m;                                               \
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

#define EXPECT_EOL() do {                                           \
	end = pcmp_set16 (m+p->off, len-p->off, crlf, 1);               \
	if (end == NULL) {                                              \
		p->off = len;                                               \
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
} while (0)



static const uint8_t crlf[] = "\r\n";
static const uint8_t version_start[] = "HTTP/1.";



#define REQ      0x00000F
#define REQ_METH 0x000001
#define REQ_URI  0x000002
#define REQ_VER  0x000003
#define REQ_EOL  0x000004

#define RES      0x0000F0
#define RES_VER  0x000010
#define RES_SEP  0x000020
#define RES_CODE 0x000030
#define RES_MSG  0x000040

#define FLD      0x000F00
#define FLD_KEY  0x000100
#define FLD_LWS  0x000200
#define FLD_VAL  0x000300

#define BODY     0x00F000

#define DONE     0xF00000

static int
scrape_field (HTTPParser *restrict p, const uint8_t *restrict m, HTTPValue *val)
{
	if (LEQ16 ("content-length", m + val->as.field.name_off, val->as.field.name_len)) {
		if (val->as.field.value_len == 0) {
			YIELD_ERROR (HTTP_PARSER_EPROTO);
		}
		size_t num = 0;
		const uint8_t *s = m + val->as.field.value_off;
		const uint8_t *e = s + val->as.field.value_len;
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

	if (LEQ ("transfer-encoding", m + val->as.field.name_off, val->as.field.name_len) &&
			LEQ16 ("chunked", m + val->as.field.value_off, val->as.field.value_len)) {
		p->chunked = true;
		return 0;
	}

	return 0;
}

static ssize_t
parse_request_line (HTTPParser *restrict p, const uint8_t *restrict m, size_t len, HTTPValue *out)
{
	static const uint8_t method_sep[] = "\0@[`{\xff"; // must match ' '
	static const uint8_t uri_sep[] = "\0 \x7f\xff"; // must match ' '

	out->type = HTTP_PARSER_NONE;

	const uint8_t *end;

	switch (p->cs) {
	case REQ:
		p->cs = REQ_METH;
		out->as.request.method_off = (uint8_t)p->off;

	case REQ_METH:
		EXPECT_RANGE_THEN_CHAR (method_sep, ' ');
		out->as.request.method_len = (uint8_t)(p->off - 1);
		if (pcmp_unlikely (out->as.request.method_len > HTTP_PARSER_MAX_METHOD)) {
			YIELD_ERROR (HTTP_PARSER_ESIZE);
		}
		p->cs = REQ_URI;
		out->as.request.uri_off = p->off;

	case REQ_URI:
		EXPECT_RANGE_THEN_CHAR (uri_sep, ' ');
		out->as.request.uri_len = (uint16_t)(p->off - 1 - out->as.request.uri_off);
		if (pcmp_unlikely (out->as.request.uri_len > HTTP_PARSER_MAX_URI)) {
			YIELD_ERROR (HTTP_PARSER_ESIZE);
		}
		p->cs = REQ_VER;

	case REQ_VER:
		EXPECT_PREFIX (version_start, 1);
		if (!isdigit (*end)) {
			YIELD_ERROR (HTTP_PARSER_EPROTO);
		}
		out->as.request.version = (uint8_t)(*end - '0');
		p->cs = REQ_EOL;

	case REQ_EOL:
		EXPECT_PREFIX (crlf, 0);
		YIELD (HTTP_PARSER_REQUEST, FLD);

	default:
		YIELD_ERROR (HTTP_PARSER_ESTATE);
	}
}

static ssize_t
parse_response_line (HTTPParser *restrict p, const uint8_t *restrict m, size_t len, HTTPValue *out)
{
	out->type = HTTP_PARSER_NONE;

	const uint8_t *end;

	switch (p->cs) {
	case RES:
		p->cs = RES_VER;

	case RES_VER:
		EXPECT_PREFIX (version_start, 1);
		if (!isdigit (*end)) {
			YIELD_ERROR (HTTP_PARSER_EPROTO);
		}
		out->as.response.version = (uint8_t)(*end - '0');
		p->cs = RES_SEP;
	
	case RES_SEP:
		EXPECT_CHAR (' ');
		p->cs = RES_CODE;
		out->as.response.status = 0;

	case RES_CODE:
		do {
			if (p->off == len) return 0;
			int c = m[p->off];
			if (c == ' ') {
				p->off++;
				break;
			}
			if (isdigit (c)) {
				out->as.response.status = out->as.response.status * 10 + (c - '0');
				p->off++;
			}
			else {
				YIELD_ERROR (HTTP_PARSER_EPROTO);
			}
		} while (true);
		out->as.response.reason_off = p->off;
		p->cs = RES_MSG;

	case RES_MSG:
		EXPECT_EOL ();
		out->as.response.reason_len = (uint16_t)(p->off - out->as.response.reason_off - (sizeof crlf - 1));
		if (pcmp_unlikely (out->as.response.reason_len > HTTP_PARSER_MAX_REASON)) {
			YIELD_ERROR (HTTP_PARSER_ESIZE);
		}
		YIELD (HTTP_PARSER_RESPONSE, FLD);

	default:
		YIELD_ERROR (HTTP_PARSER_ESTATE);
	}
}

static ssize_t
parse_field (HTTPParser *restrict p, const uint8_t *restrict m, size_t len, HTTPValue *out)
{
	static const uint8_t field_sep[] = ":@\0 \"\"()[]//{{}}"; // must match ':', allows commas
	static const uint8_t field_lws[] = "\0\x08\x0A\x1f!\xff";

	out->type = HTTP_PARSER_NONE;

	const uint8_t *end;

	switch (p->cs) {
	case FLD:
		if (len < sizeof crlf - 1) {
			return 0;
		}
		if (m[0] == crlf[0] && m[1] == crlf[1]) {
			end = m + 2;
			YIELD (HTTP_PARSER_HEADER_END, BODY);
		}
		p->cs = FLD_KEY;
		out->as.field.name_off = 0;

	case FLD_KEY:
		EXPECT_RANGE_THEN_CHAR (field_sep, ':');
		out->as.field.name_len = (uint16_t)(p->off - 1);
		if (pcmp_unlikely (out->as.field.name_len > HTTP_PARSER_MAX_FIELD)) {
			YIELD_ERROR (HTTP_PARSER_ESIZE);
		}
		p->cs = FLD_LWS;

	case FLD_LWS:
		EXPECT_RANGE (field_lws);
		out->as.field.value_off = (uint16_t)p->off;
		p->cs = FLD_VAL;

	case FLD_VAL:
		EXPECT_EOL ();
		out->as.field.value_len = (uint16_t)(p->off - out->as.field.value_off - (sizeof crlf - 1));
		if (pcmp_unlikely (out->as.field.value_len > HTTP_PARSER_MAX_VALUE)) {
			YIELD_ERROR (HTTP_PARSER_ESIZE);
		}
		scrape_field (p, m, out);
		YIELD (HTTP_PARSER_HEADER_FIELD, FLD);

	default:
		YIELD_ERROR (HTTP_PARSER_ESTATE);
	}
}

static ssize_t
parse_body (HTTPParser *restrict p, const uint8_t *restrict m, size_t len, HTTPValue *out)
{
	(void)m;
	// TODO: chunked
	out->as.body.value_off = 0;
	if (p->off + len >= p->body_len) {
		out->as.body.value_len = p->body_len - p->off;
		p->off = 0;
		p->cs = DONE;
	}
	else {
		out->as.body.value_len = len;
		p->off += len;
	}
	out->type = HTTP_PARSER_BODY;
	return len;
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
http_parser_next (HTTPParser *p, HTTPValue *out, const void *restrict buf, size_t len)
{
	p->scans++;
	if (p->cs & REQ)  return parse_request_line (p, buf, len, out);
	if (p->cs & RES)  return parse_response_line (p, buf, len, out);
	if (p->cs & FLD)  return parse_field (p, buf, len, out);
	if (p->cs & BODY) return parse_body (p, buf, len, out);
	YIELD_ERROR (HTTP_PARSER_ESTATE);
}

bool
http_parser_is_done (const HTTPParser *p)
{
	assert (p != NULL);

	return p->cs == DONE;
}

