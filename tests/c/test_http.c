#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include "http.h"
#include "mu.h"

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

static const uint8_t request[] = 
	"GET /some/path HTTP/1.1\r\n"
	"Empty:\r\n"
	"Empty-Space: \r\n"
	"Space: value\r\n"
	"No-Space:value\r\n"
	"Spaces: value with spaces\r\n"
	"Pre-Spaces:           value with prefix spaces\r\n"
	"Content-Length: 13\r\n"
	//"Newlines: stuff\r\n with\r\n newlines\r\n"
	//"String: stuff\r\n \"with\r\n\\\"strings\\\" and things\r\n\"\r\n"
	"\r\n"
	"Hello World!\n"
	;

static const uint8_t response[] = 
	"HTTP/1.1 200 OK\r\n"
	"Empty:\r\n"
	"Empty-Space: \r\n"
	"Space: value\r\n"
	"No-Space:value\r\n"
	"Spaces: value with spaces\r\n"
	"Pre-Spaces:           value with prefix spaces\r\n"
	"Content-Length: 13\r\n"
	//"Newlines: stuff\r\n with\r\n newlines\r\n"
	//"String: stuff\r\n \"with\r\n\\\"strings\\\" and things\r\n\"\r\n"
	"\r\n"
	"Hello World!\n"
	;

static void
test_request_line (HTTPValue *val, const uint8_t *buf)
{
	char str[64]; // only using for string comparisons

	memcpy (str, buf + val->as.request.method_off, val->as.request.method_len);
	str[val->as.request.method_len] = '\0';
	mu_assert_str_eq ("GET", str);

	memcpy (str, buf + val->as.request.uri_off, val->as.request.uri_len);
	str[val->as.request.uri_len] = '\0';
	mu_assert_str_eq ("/some/path", str);

	mu_assert_int_eq (1, val->as.request.version);
}

static void
test_next_header_field (HTTPValue *val, const uint8_t *buf, size_t *n)
{
	static const char *headers[][2] = {
		{"Empty", ""},
		{"Empty-Space", ""},
		{"Space", "value"},
		{"No-Space", "value"},
		{"Spaces", "value with spaces"},
		{"Pre-Spaces", "value with prefix spaces"},
		{"Content-Length", "13"}
	};

	char str[64]; // only using for string comparisons

	memcpy (str, buf + val->as.field.name_off, val->as.field.name_len);
	str[val->as.field.name_len] = '\0';
	mu_assert_str_eq (headers[*n][0], str);

	memcpy (str, buf + val->as.field.value_off, val->as.field.value_len);
	str[val->as.field.value_len] = '\0';
	mu_assert_str_eq (headers[*n][1], str);

	(*n)++;
}

static void
test_next_body (HTTPValue *val, const uint8_t *buf, size_t *off)
{
	static const char body[] = "Hello World!\n";

	char str[64], cmp[64]; // only using for string comparisons

	ssize_t rem = sizeof body - 1 - *off;
	mu_assert_uint_ge (rem, val->as.body.value_len);

	if (rem >= 0 && (size_t)rem >= val->as.body.value_len) {
		memcpy (str, buf + val->as.body.value_off, val->as.body.value_len);
		str[val->as.body.value_len] = '\0';

		memcpy (cmp, body + *off, val->as.body.value_len);
		cmp[val->as.body.value_len] = '\0';

		mu_assert_str_eq (str, cmp);

		*off += val->as.body.value_len;
	}
}

static void
test_message (HTTPParser *p, const uint8_t *msg, size_t mlen, ssize_t chunk)
{
	HTTPValue val;
	const uint8_t *buf = msg;
	size_t len, trim = 0;

	if (chunk > 0) {
		len = chunk;
	}
	else {
		len = mlen;
	}

	bool header_end = false;
	size_t headern = 0;
	size_t bodyn = 0;

	while (len > 0 && !http_parser_is_done (p)) {
		mu_assert_uint_ge (len, trim);
		if (len < trim) return;

		ssize_t rc = http_parser_next (p, &val, buf, len - trim);

		// normally rc could equal 0 if a full scan couldn't be completed
		mu_assert_int_ge (rc, 0);
		if (rc < 0) {
			fprintf (stderr, "FAILED PARSING: ");
			print_string (stderr, buf, len - trim);
			return;
		}

		if (val.type == HTTP_PARSER_REQUEST) {
			test_request_line (&val, buf);
		}
		else if (val.type == HTTP_PARSER_HEADER_FIELD) {
			test_next_header_field (&val, buf, &headern);
		}
		else if (val.type == HTTP_PARSER_HEADER_END) {
			header_end = true;
		}
		else if (val.type == HTTP_PARSER_BODY) {
			test_next_body (&val, buf, &bodyn);
		}

		// trim the buffer
		buf += rc;
		trim += rc;

		if (chunk > 0) {
			len += chunk;
			if (len > mlen) {
				len = mlen;
			}
		}
	}
}

static void
test_request (ssize_t chunk)
{
	HTTPParser p;
	http_parser_init_request (&p);
	test_message (&p, request, sizeof request - 1, chunk);
}

static void
test_response (ssize_t chunk)
{
	HTTPParser p;
	http_parser_init_response (&p);
	test_message (&p, response, sizeof response - 1, chunk);
}

int
main (void)
{
	test_request (-1); // parse full message
	test_request (1);  // parse 1 byte at a time
	test_request (2);  // parse 2 bytes at a time
	test_request (11); // parse 11 bytes at a time

	test_response (-1); // parse full message
	test_response (1);  // parse 1 byte at a time
	test_response (2);  // parse 2 bytes at a time
	test_response (11); // parse 11 bytes at a time

	mu_exit ("http");
}

