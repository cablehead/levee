#include <stdlib.h>
#include <err.h>
#include <sysexits.h>
#include <signal.h>
#include <errno.h>
#include <assert.h>
#include <pthread.h>

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include "levee.h"

#include "levee_cdef.h"

struct Levee {
	lua_State *L;
	pthread_t thread;
};

extern int
luaopen_levee (lua_State *L);

Levee *
levee_create (void)
{
	lua_State *L = luaL_newstate ();
	if (L == NULL) {
		err (EX_SOFTWARE, "failed to create state");
	}

	luaL_openlibs (L);
	luaopen_levee (L);

	// put ffi module on the stack
	lua_getglobal (L, "require");
	lua_pushstring (L, "ffi");
	lua_call (L, 1, 1);

	lua_getfield (L, -1, "cdef");
	lua_pushstring (L, levee_cdef);
	lua_call (L, 1, 0);
	lua_pop (L, 1);  // pop ffi module

	Levee *self = malloc (sizeof *self);
	if (self == NULL) {
		int err = errno;
		lua_close (L);
		errno = err;
		return NULL;
	}
	self->L = L;
	return self;
}

void
levee_destroy (Levee *self)
{
	if (self == NULL) {
		return;
	}

	if (self->L) {
		lua_close (self->L);
		self->L = NULL;
	}
	free (self);
}

void
levee_set_arg (Levee *self, int argc, const char **argv)
{
	assert (self != NULL);

	lua_createtable (self->L, argc+1, 0);
	lua_pushstring (self->L, "levee");
	lua_rawseti (self->L, -2, -1);
	for (int i = 0; i < argc; i++) {
		lua_pushstring (self->L, argv[i]);
		lua_rawseti (self->L, -2, i);
	}
	lua_setglobal (self->L, "arg");
}

static void
report_error (Levee *self)
{
	assert (self != NULL);

	if (!lua_isnil (self->L, -1)) {
		const char *msg = lua_tostring (self->L, -1);
		if (msg == NULL) msg = "(error object is not a string)";
		fprintf (stderr, "levee: %s\n", msg);
		fflush (stderr);
		lua_pop (self->L, 1);
	}
}

int
levee_load_file (Levee *self, const char *path)
{
	assert (self != NULL);
	assert (path != NULL);

	if (luaL_loadfile (self->L, path)) {
		report_error (self);
		return -1;
	}
	return 0;
}

int
levee_load_script (Levee *self, const char *script, size_t len, const char *name)
{
	assert (self != NULL);
	assert (script != NULL);

	if (luaL_loadbuffer (self->L, script, len, name)) {
		report_error (self);
		return -1;
	}
	return 0;
}

int
levee_run (Levee *self, bool bg)
{
	(void)bg;
	assert (self != NULL);

	if (lua_pcall (self->L, 0, 0, 0)) {
		report_error (self);
		return -1;
	}
	return 0;
}

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
	if (levee_load_file (state, argv[1]) || levee_run (state, false)) {
		rc = EX_DATAERR;
	}
	levee_destroy (state);
	return rc;
}

