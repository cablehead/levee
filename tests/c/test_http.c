#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include "http.h"
#include "mu.h"

typedef struct {
	union {
		struct {
			char method[8];
			char uri[32];
			uint8_t version;
		} request;
		struct {
			uint8_t version;
			uint16_t status;
			char reason[32];
		} response;
	} as;
	struct {
		char name[32];
		char value[64];
	} fields[16];
	size_t field_count;
	char body[256];
} Message;

static void
print_string (FILE *out, const void *val, size_t len)
{
	for (const uint8_t *p = val, *pe = p + len; p < pe; p++) {
		if (isprint (*p)) {
			fputc (*p, out);
		}
		else if (*p >= '\a' && *p <= '\r') {
			static const char tab[] = "abtnvfr";
			fprintf (out, "\\%c", tab[*p - '\a']);
		}
		else {
			fprintf (out, "\\x%02X", *p);
		}
	}
	fputc ('\n', out);
}

static bool
parse (HTTPParser *p, Message *msg, const uint8_t *in, size_t inlen, ssize_t speed)
{
	memset (msg, 0, sizeof *msg);

	const uint8_t *buf = in;
	size_t len, trim = 0;
	size_t body = 0;
	ssize_t rc;

	if (speed > 0) {
		len = speed;
	}
	else {
		len = inlen;
	}

	while (body > 0 || !http_parser_is_done (p)) {
		mu_assert_uint_ge (len, trim);
		if (len < trim) return false;

		if (body > 0) {
			rc = len - trim;
			if (body < (size_t)rc) {
				rc = body;
			}
			strncat (msg->body, (char *)buf, rc);
			body -= rc;
		}
		else {
			rc = http_parser_next (p, buf, len - trim);

			// normally rc could equal 0 if a full scan couldn't be completed
			mu_assert_int_ge (rc, 0);
			if (rc < 0) {
				fprintf (stderr, "FAILED PARSING: ");
				print_string (stderr, buf, len - trim);
				return false;
			}

			if (p->type == HTTP_PARSER_REQUEST) {
				strncat (msg->as.request.method,
						(char *)buf + p->as.request.method_off,
						p->as.request.method_len);
				strncat (msg->as.request.uri,
						(char *)buf + p->as.request.uri_off,
						p->as.request.uri_len);
				msg->as.request.version = p->as.request.version;
			}
			else if (p->type == HTTP_PARSER_RESPONSE) {
				msg->as.response.version = p->as.response.version;
				msg->as.response.status = p->as.response.status;
				strncat (msg->as.response.reason,
						(char *)buf + p->as.response.reason_off,
						p->as.response.reason_len);
			}
			else if (p->type == HTTP_PARSER_FIELD) {
				strncat (msg->fields[msg->field_count].name,
						(char *)buf + p->as.field.name_off,
						p->as.field.name_len);
				strncat (msg->fields[msg->field_count].value,
						(char *)buf + p->as.field.value_off,
						p->as.field.value_len);
				msg->field_count++;
			}
			else if (p->type == HTTP_PARSER_BODY_START) {
				if (!p->as.body_start.chunked) {
					body = p->as.body_start.content_length;
				}
			}
			else if (p->type == HTTP_PARSER_BODY_CHUNK) {
				body = p->as.body_chunk.length;
			}
		}

		// trim the buffer
		buf += rc;
		trim += rc;

		if (speed > 0) {
			len += speed;
			if (len > inlen) {
				len = inlen;
			}
		}
	}

	return true;
}

static void
test_request (ssize_t speed)
{
	HTTPParser p;
	http_parser_init_request (&p);

	static const uint8_t request[] = 
		"GET /some/path HTTP/1.1\r\n"
		"Empty:\r\n"
		"Empty-Space: \r\n"
		"Space: value\r\n"
		"No-Space:value\r\n"
		"Spaces: value with spaces\r\n"
		"Pre-Spaces:           value with prefix spaces\r\n"
		"Content-Length: 12\r\n"
		//"Newlines: stuff\r\n with\r\n newlines\r\n"
		//"String: stuff\r\n \"with\r\n\\\"strings\\\" and things\r\n\"\r\n"
		"\r\n"
		"Hello World!"
		;

	Message msg;
	if (!parse (&p, &msg, request, sizeof request - 1, speed)) {
		return;
	}

	mu_assert_str_eq ("GET", msg.as.request.method);
	mu_assert_str_eq ("/some/path", msg.as.request.uri);
	mu_assert_uint_eq (1, msg.as.request.version);
	mu_assert_uint_eq (7, msg.field_count);
	mu_assert_str_eq ("Empty", msg.fields[0].name);
	mu_assert_str_eq ("", msg.fields[0].value);
	mu_assert_str_eq ("Empty-Space", msg.fields[1].name);
	mu_assert_str_eq ("", msg.fields[1].value);
	mu_assert_str_eq ("Space", msg.fields[2].name);
	mu_assert_str_eq ("value", msg.fields[2].value);
	mu_assert_str_eq ("No-Space", msg.fields[3].name);
	mu_assert_str_eq ("value", msg.fields[3].value);
	mu_assert_str_eq ("Spaces", msg.fields[4].name);
	mu_assert_str_eq ("value with spaces", msg.fields[4].value);
	mu_assert_str_eq ("Pre-Spaces", msg.fields[5].name);
	mu_assert_str_eq ("value with prefix spaces", msg.fields[5].value);
	mu_assert_str_eq ("Content-Length", msg.fields[6].name);
	mu_assert_str_eq ("12", msg.fields[6].value);
	mu_assert_str_eq ("Hello World!", msg.body);
}

static void
test_chunked_request (ssize_t speed)
{
	HTTPParser p;
	http_parser_init_request (&p);

	static const uint8_t request[] = 
		"GET /some/path HTTP/1.1\r\n"
		"Empty:\r\n"
		"Empty-Space: \r\n"
		"Space: value\r\n"
		"No-Space:value\r\n"
		"Spaces: value with spaces\r\n"
		"Pre-Spaces:           value with prefix spaces\r\n"
		"Transfer-Encoding: chunked\r\n"
		//"Newlines: stuff\r\n with\r\n newlines\r\n"
		//"String: stuff\r\n \"with\r\n\\\"strings\\\" and things\r\n\"\r\n"
		"\r\n"
		"5\r\n"
		"Hello"
		"7\r\n"
		" World!"
		"0\r\n"
		"Trailer: trailer value\r\n"
		"\r\n"
		;

	Message msg;
	if (!parse (&p, &msg, request, sizeof request - 1, speed)) {
		return;
	}

	mu_assert_str_eq ("GET", msg.as.request.method);
	mu_assert_str_eq ("/some/path", msg.as.request.uri);
	mu_assert_uint_eq (1, msg.as.request.version);
	mu_assert_uint_eq (8, msg.field_count);
	mu_assert_str_eq ("Empty", msg.fields[0].name);
	mu_assert_str_eq ("", msg.fields[0].value);
	mu_assert_str_eq ("Empty-Space", msg.fields[1].name);
	mu_assert_str_eq ("", msg.fields[1].value);
	mu_assert_str_eq ("Space", msg.fields[2].name);
	mu_assert_str_eq ("value", msg.fields[2].value);
	mu_assert_str_eq ("No-Space", msg.fields[3].name);
	mu_assert_str_eq ("value", msg.fields[3].value);
	mu_assert_str_eq ("Spaces", msg.fields[4].name);
	mu_assert_str_eq ("value with spaces", msg.fields[4].value);
	mu_assert_str_eq ("Pre-Spaces", msg.fields[5].name);
	mu_assert_str_eq ("value with prefix spaces", msg.fields[5].value);
	mu_assert_str_eq ("Transfer-Encoding", msg.fields[6].name);
	mu_assert_str_eq ("chunked", msg.fields[6].value);
	mu_assert_str_eq ("Trailer", msg.fields[7].name);
	mu_assert_str_eq ("trailer value", msg.fields[7].value);
	mu_assert_str_eq ("Hello World!", msg.body);
}

static void
test_response (ssize_t speed)
{
	HTTPParser p;
	http_parser_init_response (&p);

	static const uint8_t response[] = 
		"HTTP/1.1 200 OK\r\n"
		"Empty:\r\n"
		"Empty-Space: \r\n"
		"Space: value\r\n"
		"No-Space:value\r\n"
		"Spaces: value with spaces\r\n"
		"Pre-Spaces:           value with prefix spaces\r\n"
		"Content-Length: 12\r\n"
		//"Newlines: stuff\r\n with\r\n newlines\r\n"
		//"String: stuff\r\n \"with\r\n\\\"strings\\\" and things\r\n\"\r\n"
		"\r\n"
		"Hello World!"
		;

	Message msg;
	if (!parse (&p, &msg, response, sizeof response - 1, speed)) {
		return;
	}

	mu_assert_uint_eq (1, msg.as.response.version);
	mu_assert_uint_eq (200, msg.as.response.status);
	mu_assert_str_eq ("OK", msg.as.response.reason);
	mu_assert_uint_eq (7, msg.field_count);
	mu_assert_str_eq ("Empty", msg.fields[0].name);
	mu_assert_str_eq ("", msg.fields[0].value);
	mu_assert_str_eq ("Empty-Space", msg.fields[1].name);
	mu_assert_str_eq ("", msg.fields[1].value);
	mu_assert_str_eq ("Space", msg.fields[2].name);
	mu_assert_str_eq ("value", msg.fields[2].value);
	mu_assert_str_eq ("No-Space", msg.fields[3].name);
	mu_assert_str_eq ("value", msg.fields[3].value);
	mu_assert_str_eq ("Spaces", msg.fields[4].name);
	mu_assert_str_eq ("value with spaces", msg.fields[4].value);
	mu_assert_str_eq ("Pre-Spaces", msg.fields[5].name);
	mu_assert_str_eq ("value with prefix spaces", msg.fields[5].value);
	mu_assert_str_eq ("Content-Length", msg.fields[6].name);
	mu_assert_str_eq ("12", msg.fields[6].value);
	mu_assert_str_eq ("Hello World!", msg.body);
}

static void
test_chunked_response (ssize_t speed)
{
	HTTPParser p;
	http_parser_init_response (&p);

	static const uint8_t response[] = 
		"HTTP/1.1 200 OK\r\n"
		"Empty:\r\n"
		"Empty-Space: \r\n"
		"Space: value\r\n"
		"No-Space:value\r\n"
		"Spaces: value with spaces\r\n"
		"Pre-Spaces:           value with prefix spaces\r\n"
		"Transfer-Encoding: chunked\r\n"
		//"Newlines: stuff\r\n with\r\n newlines\r\n"
		//"String: stuff\r\n \"with\r\n\\\"strings\\\" and things\r\n\"\r\n"
		"\r\n"
		"5\r\n"
		"Hello"
		"7\r\n"
		" World!"
		"0\r\n"
		"Trailer: trailer value\r\n"
		"\r\n"
		;

	Message msg;
	if (!parse (&p, &msg, response, sizeof response - 1, speed)) {
		return;
	}

	mu_assert_uint_eq (1, msg.as.response.version);
	mu_assert_uint_eq (200, msg.as.response.status);
	mu_assert_str_eq ("OK", msg.as.response.reason);
	mu_assert_uint_eq (8, msg.field_count);
	mu_assert_str_eq ("Empty", msg.fields[0].name);
	mu_assert_str_eq ("", msg.fields[0].value);
	mu_assert_str_eq ("Empty-Space", msg.fields[1].name);
	mu_assert_str_eq ("", msg.fields[1].value);
	mu_assert_str_eq ("Space", msg.fields[2].name);
	mu_assert_str_eq ("value", msg.fields[2].value);
	mu_assert_str_eq ("No-Space", msg.fields[3].name);
	mu_assert_str_eq ("value", msg.fields[3].value);
	mu_assert_str_eq ("Spaces", msg.fields[4].name);
	mu_assert_str_eq ("value with spaces", msg.fields[4].value);
	mu_assert_str_eq ("Pre-Spaces", msg.fields[5].name);
	mu_assert_str_eq ("value with prefix spaces", msg.fields[5].value);
	mu_assert_str_eq ("Transfer-Encoding", msg.fields[6].name);
	mu_assert_str_eq ("chunked", msg.fields[6].value);
	mu_assert_str_eq ("Trailer", msg.fields[7].name);
	mu_assert_str_eq ("trailer value", msg.fields[7].value);
	mu_assert_str_eq ("Hello World!", msg.body);
}

static void
test_invalid_header (void)
{
	static const uint8_t request[] = 
		"GET /some/path HTTP/1.1\r\n"
		"Header\r\n"
		"\r\n"
		;

	HTTPParser p;
	ssize_t rc;

	http_parser_init_request (&p);
	rc = http_parser_next (&p, request, sizeof request - 1);
	mu_assert_int_eq (rc, 25);
	if (rc > 0) {
		mu_assert_int_eq (p.type, HTTP_PARSER_REQUEST);
		rc = http_parser_next (&p, request + rc, sizeof request - 1 - rc);
		mu_assert_int_eq (rc, HTTP_PARSER_EPROTO);
	}
}

static void
test_limit_method_size (void)
{
	static const uint8_t request[] = 
		"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX /some/path HTTP/1.1\r\n"
		"\r\n"
		"\r\n"
		;

	HTTPParser p;
	ssize_t rc;

	http_parser_init_request (&p);
	rc = http_parser_next (&p, request, sizeof request - 1);
	mu_assert_int_eq (rc, 54);
}

static void
test_exceed_method_size (void)
{
	static const uint8_t request[] = 
		"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX /some/path HTTP/1.1\r\n"
		"\r\n"
		"\r\n"
		;

	HTTPParser p;
	ssize_t rc;

	http_parser_init_request (&p);
	rc = http_parser_next (&p, request, sizeof request - 1);
	mu_assert_int_eq (rc, HTTP_PARSER_ESIZE);
}

static void
test_limit_name_size (void)
{
	static const uint8_t request[] = 
		"GET /some/path HTTP/1.1\r\n"
		"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX: value\r\n"
		"\r\n"
		;

	HTTPParser p;
	ssize_t rc;

	http_parser_init_request (&p);
	rc = http_parser_next (&p, request, sizeof request - 1);
	mu_assert_int_eq (rc, 25);
	if (rc > 0) {
		mu_assert_int_eq (p.type, HTTP_PARSER_REQUEST);
		rc = http_parser_next (&p, request + rc, sizeof request - 1 - rc);
		mu_assert_int_eq (rc, 265);
	}
}

static void
test_exceed_name_size (void)
{
	static const uint8_t request[] = 
		"GET /some/path HTTP/1.1\r\n"
		"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX: value\r\n"
		"\r\n"
		;

	HTTPParser p;
	ssize_t rc;

	http_parser_init_request (&p);
	rc = http_parser_next (&p, request, sizeof request - 1);
	mu_assert_int_eq (rc, 25);
	if (rc > 0) {
		mu_assert_int_eq (p.type, HTTP_PARSER_REQUEST);
		rc = http_parser_next (&p, request + rc, sizeof request - 1 - rc);
		mu_assert_int_eq (rc, HTTP_PARSER_ESIZE);
	}
}

static void
test_limit_value_size (void)
{
	static const uint8_t request[] = 
		"GET /some/path HTTP/1.1\r\n"
		"Name:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\r\n"
		"\r\n"
		;

	HTTPParser p;
	ssize_t rc;

	http_parser_init_request (&p);
	rc = http_parser_next (&p, request, sizeof request - 1);
	mu_assert_int_eq (rc, 25);
	if (rc > 0) {
		mu_assert_int_eq (p.type, HTTP_PARSER_REQUEST);
		rc = http_parser_next (&p, request + rc, sizeof request - 1 - rc);
		mu_assert_int_eq (rc, 1031);
	}
}

static void
test_exceed_value_size (void)
{
	static const uint8_t request[] = 
		"GET /some/path HTTP/1.1\r\n"
		"Name:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\r\n"
		"\r\n"
		;

	HTTPParser p;
	ssize_t rc;

	http_parser_init_request (&p);
	rc = http_parser_next (&p, request, sizeof request - 1);
	mu_assert_int_eq (rc, 25);
	if (rc > 0) {
		mu_assert_int_eq (p.type, HTTP_PARSER_REQUEST);
		rc = http_parser_next (&p, request + rc, sizeof request - 1 - rc);
		mu_assert_int_eq (rc, HTTP_PARSER_ESIZE);
	}
}


int
main (void)
{
	test_request (-1); // parse full message
	test_request (1);  // parse 1 byte at a time
	test_request (2);  // parse 2 bytes at a time
	test_request (11); // parse 11 bytes at a time

	test_chunked_request (-1); // parse full message
	test_chunked_request (1);  // parse 1 byte at a time
	test_chunked_request (2);  // parse 2 bytes at a time
	test_chunked_request (11); // parse 11 bytes at a time

	test_response (-1); // parse full message
	test_response (1);  // parse 1 byte at a time
	test_response (2);  // parse 2 bytes at a time
	test_response (11); // parse 11 bytes at a time

	test_chunked_response (-1); // parse full message
	test_chunked_response (1);  // parse 1 byte at a time
	test_chunked_response (2);  // parse 2 bytes at a time
	test_chunked_response (11); // parse 11 bytes at a time

	test_invalid_header ();

	test_limit_method_size ();
	test_exceed_method_size ();
	test_limit_name_size ();
	test_exceed_name_size ();
	test_limit_value_size ();
	test_exceed_value_size ();

	mu_exit ("http");
}

