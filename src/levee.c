#include <stdlib.h>
#include <err.h>
#include <sysexits.h>

#include "levee.h"
#include "task.h"

#include "levee_cdef.h"

extern int
luaopen_levee (lua_State *L);

static void
message (const char *pname, const char *msg)
{
	fprintf (stderr, "%s: %s\n", pname, msg);
	fflush (stderr);
}

static void
report (lua_State *L, const char *pname, int status)
{
	if (status && !lua_isnil (L, -1)) {
		const char *msg = lua_tostring (L, -1);
		if (msg == NULL) msg = "(error object is not a string)";
		message (pname, msg);
		lua_pop (L, 1);
	}
}

int
main (int argc, const char *argv[])
{
	if (argc < 2) {
		errx (EX_NOINPUT, "script required");
	}

	lua_State *L = luaL_newstate ();
	if (L == NULL) {
		err (EX_SOFTWARE, "failed to create state");
	}

	luaL_openlibs (L);
	luaopen_levee (L);
	luaL_findtable (L, LUA_REGISTRYINDEX, "_PRELOAD", 16);
	lua_pushcfunction (L, luaopen_task);
	lua_setfield (L, -2, "levee.task");

	// put ffi module on the stack
	lua_getglobal (L, "require");
	lua_pushstring (L, "ffi");
	lua_call (L, 1, 1);

	lua_getfield (L, -1, "cdef");
	lua_pushstring (L, levee_cdef);
	lua_call (L, 1, 0);
	lua_pop (L, 1);  // pop ffi module

	lua_State *task = lua_newthread (L);
	lua_createtable (task, argc, 0);
	lua_pushstring (task, "levee");
	lua_rawseti (task, -2, -1);
	for (int i = 1; i < argc; i++) {
		lua_pushstring (task, argv[i]);
		lua_rawseti (task, -2, i-1);
	}
	lua_setglobal (task, "arg");

	int rc = 0;
	if (luaL_loadfile (task, argv[1]) || lua_pcall (task, 0, 0, 0)) {
		rc = EX_DATAERR;
	}
	report (task, "levee", rc);
	lua_close (L);
	return rc;
}

