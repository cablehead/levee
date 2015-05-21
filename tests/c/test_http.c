#include <stdio.h>
#include <stdlib.h>
#include "http.h"
#include "mu.h"

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

static void
test_request (void)
{
	HTTPParser p;
	HTTPValue val;
	ssize_t rc;
	const uint8_t *buf = request;
	ssize_t len = sizeof request - 1;
	bool header_end = false;

	char str[256]; // only using for string comparisons

	const char *headers[][2] = {
		{"Empty", ""},
		{"Empty-Space", ""},
		{"Space", "value"},
		{"No-Space", "value"},
		{"Spaces", "value with spaces"},
		{"Pre-Spaces", "value with prefix spaces"},
		{"Content-Length", "13"}
	};
	size_t headern = 0;

	http_parser_init_request (&p);

	while (len > 0) {
		rc = http_parser_next (&p, &val, buf, len);

		// normally rc could equal 0 if a full scan couldn't be completed
		mu_assert_uint_lt (0, rc);

		if (val.type == HTTP_PARSER_REQUEST) {
			memcpy (str, buf + val.as.request.method_off, val.as.request.method_len);
			str[val.as.request.method_len] = '\0';
			mu_assert_str_eq ("GET", str);

			memcpy (str, buf + val.as.request.uri_off, val.as.request.uri_len);
			str[val.as.request.uri_len] = '\0';
			mu_assert_str_eq ("/some/path", str);

			mu_assert_int_eq (1, val.as.request.version);
		}
		else if (val.type == HTTP_PARSER_HEADER_FIELD) {
			memcpy (str, buf + val.as.field.name_off, val.as.field.name_len);
			str[val.as.field.name_len] = '\0';
			mu_assert_str_eq (headers[headern][0], str);

			memcpy (str, buf + val.as.field.value_off, val.as.field.value_len);
			str[val.as.field.value_len] = '\0';
			mu_assert_str_eq (headers[headern][1], str);

			headern++;
		}
		else if (val.type == HTTP_PARSER_HEADER_END) {
			header_end = true;
		}
		else if (val.type == HTTP_PARSER_BODY) {
			mu_assert_int_eq (true, header_end);
			memcpy (str, buf + val.as.body.value_off, val.as.body.value_len);
			str[val.as.body.value_len] = '\0';
			mu_assert_str_eq ("Hello World!\n", str);
		}

		// trim the buffer
		buf += rc;
		len -= rc;
	}
}

int
main (void)
{
	test_request ();
	mu_exit ("http");
}

