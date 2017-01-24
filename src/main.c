#include <stdlib.h>
#include <signal.h>
#include <sysexits.h>
#include <err.h>

#include "levee.h"

static Levee *state;

static int
pmain (lua_State *L)
{
	(void)L;
	int n = levee_require (state, "levee.main");
	if (n > 0) {
		lua_pop (L, n);
	}
	return 0;
}

static void
cleanup (void)
{
	levee_destroy (state);
	state = NULL;
}

int
main (int argc, const char *argv[])
{
	signal (SIGPIPE, SIG_IGN);

	atexit (cleanup);

	state = levee_create ();
	levee_set_arg (state, argc, argv);

	int rc = 0;
	if (!levee_runf (state, pmain, 0, false)) {
		levee_report_error (state);
		rc = EX_DATAERR;
	}
	levee_destroy (state);
	state = NULL;
	return rc;
}

