#include <signal.h>
#include <sysexits.h>
#include <err.h>

#include "levee.h"

int
main (int argc, const char *argv[])
{
	if (argc < 2) {
		errx (EX_NOINPUT, "script required");
	}

	signal (SIGPIPE, SIG_IGN);

	Levee *state = levee_create ();
	levee_set_arg (state, argc-1, argv+1);

	int rc = 0;
	if (!levee_load_file (state, argv[1]) || !levee_run (state, 0, false)) {
		levee_report_error (state);
		rc = EX_DATAERR;
	}
	levee_destroy (state);
	return rc;
}
