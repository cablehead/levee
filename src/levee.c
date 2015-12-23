#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <err.h>
#include <sysexits.h>
#include <errno.h>
#include <assert.h>
#include <pthread.h>
#include <sys/socket.h>

#ifdef __linux__
# include <sys/sendfile.h>
#endif

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include "levee.h"
#include "levee_cdef.h"


#define LEVEE_LOCAL 0
#define LEVEE_BG 1

static const LeveeConfig *config = NULL;

extern int
luaopen_levee (lua_State *L);

extern int
luaopen_lpeg (lua_State *L);

static int
require (lua_State *L, const char *name)
{
	lua_getglobal (L, "require");
	lua_pushstring (L, name);
	lua_call (L, 1, 1);
	return 1;
}

static int
levee_dsym_loader (lua_State *L) {
	size_t len;
	const char *target = lua_tolstring (L, 1, &len);
	const char *offset = strchr (target, (int) '.');
	if (offset != NULL) { len = offset - target; }

	static const char prefix[] = "luaopen_";
	size_t symsize = len + sizeof (prefix);
	char sym[symsize];
	snprintf (sym, symsize, "luaopen_%.*s", (int) len, target);

	lua_CFunction f;
	f = (lua_CFunction) dlsym (RTLD_SELF, sym);

	if (f != NULL) {
		f (L);
		lua_getfield (L, LUA_REGISTRYINDEX, "_PRELOAD");
		lua_getfield (L, -1, target);
		lua_remove (L, 2);  // remove _PRELOAD
		return 1;
	}

	char msg[symsize + 20];
	snprintf (msg, sizeof(msg), "\tno symbol: %s", sym);
	lua_pushstring (L, msg);
	return 1;
}

void levee_insert_dsym_loader (lua_State *L) {
	lua_getglobal (L, "table");
	lua_pushstring (L, "insert");
	lua_gettable (L, 1);
	lua_remove (L, 1);  // remove table

	lua_getglobal (L, "package");
	lua_pushstring (L, "loaders");
	lua_gettable (L, 2);
	lua_remove (L, 2);  // remove package

	lua_pushnumber (L, 2);
	lua_pushcfunction (L, levee_dsym_loader);
	lua_call (L, 3, 0);
}

void
levee_init (const LeveeConfig *cfg)
{
	const LeveeConfig *old;
	do {
		old = config;
	} while (!__sync_bool_compare_and_swap (&config, old, cfg));
}

static void
register_3rd_party (lua_State *L)
{
	static const luaL_Reg libs[] = {
		{ "lpeg", luaopen_lpeg },
		{ NULL, NULL }
	};

	const luaL_Reg *lib;

	luaL_findtable (L, LUA_REGISTRYINDEX, "_PRELOAD", 16);
	for (lib = libs; lib->name != NULL; lib++) {
		lua_pushcfunction (L, lib->func);
		lua_setfield (L, -2, lib->name);
	}
}

Levee *
levee_create (void)
{
	lua_State *L = luaL_newstate ();
	if (L == NULL) {
		err (EX_SOFTWARE, "failed to create state");
	}

	luaL_openlibs (L);
	luaopen_levee (L);
	register_3rd_party (L);

	// put ffi module on the stack
	require (L, "ffi");

	lua_getfield (L, -1, "cdef");
	lua_pushstring (L, levee_cdef);
	lua_call (L, 1, 0);
	lua_pop (L, 1);  // pop ffi module

	require (L, "levee.core.thread");
	lua_pop (L, 1); // pop levee.core.channel module

	__sync_synchronize ();
	const LeveeConfig *cfg = config;
	if (cfg != NULL && cfg->init != NULL) {
		cfg->init (L);
	}

	Levee *self = malloc (sizeof *self);
	if (self == NULL) {
		int err = errno;
		lua_close (L);
		errno = err;
		return NULL;
	}
	self->L = L;
	self->state = LEVEE_LOCAL;
	self->last_error = NULL;
	return self;
}

static void
destroy (Levee *self)
{
	if (self->L) {
		lua_close (self->L);
		self->L = NULL;
	}
	free (self->last_error);
	free (self);
}

void
levee_destroy (Levee *self)
{
	if (self == NULL) {
		return;
	}
	if (self->state != LEVEE_LOCAL) {
		return;
	}
	destroy (self);
}

int
levee_require (Levee *self, const char *name)
{
	return require (self->L, name);
}

void
levee_set_arg (Levee *self, int argc, const char **argv)
{
	assert (self != NULL);

	if (self->state != LEVEE_LOCAL) {
		return;
	}

	lua_createtable (self->L, argc+1, 0);
	lua_pushstring (self->L, "levee");
	lua_rawseti (self->L, -2, 0);
	for (int i = 0; i < argc; i++) {
		lua_pushstring (self->L, argv[i]);
		lua_rawseti (self->L, -2, i+1);
	}
	lua_setglobal (self->L, "arg");
}

const char *
levee_get_error (Levee *self)
{
	static const char *invalid_type = "(error object is not a string)";
	static const char *oom = "(out of memory)";
	static const char *bg = "invalid access of background state";

	if (self->state != LEVEE_LOCAL) {
		return bg;
	}

	const char *ret = NULL;

	free (self->last_error);
	self->last_error = NULL;

	if (!lua_isnil (self->L, -1)) {
		size_t len;
		const char *msg = lua_tolstring (self->L, -1, &len);
		if (msg == NULL) {
			ret = invalid_type;
		}
		else {
			self->last_error = strndup (msg, len);
			if (self->last_error == NULL) {
				ret = oom;
			}
			else {
				ret = self->last_error;
			}
		}
		lua_pop (self->L, 1);
	}

	return ret;
}

void
levee_report_error (Levee *self)
{
	assert (self != NULL);

	const char *msg = levee_get_error (self);
	if (msg) {
		fprintf (stderr, "levee: %s\n", msg);
		fflush (stderr);
		lua_pop (self->L, 1);
	}
}

bool
levee_load_file (Levee *self, const char *path)
{
	assert (self != NULL);
	assert (path != NULL);

	if (self->state != LEVEE_LOCAL) {
		return false;
	}
	if (luaL_loadfile (self->L, path)) {
		return false;
	}
	return true;
}

bool
levee_load_string (Levee *self, const char *script, size_t len, const char *name)
{
	assert (self != NULL);
	assert (script != NULL);

	if (self->state != LEVEE_LOCAL) {
		return false;
	}
	if (luaL_loadbuffer (self->L, script, len, name)) {
		return false;
	}
	return true;
}

static void *
run (void *data)
{
	Levee *self = data;

	if (lua_pcall (self->L, self->narg, 0, 0)) {
		return false;
	}
	destroy (self);
	return NULL;
}

bool
levee_run (Levee *self, int narg, bool bg)
{
	assert (self != NULL);

	if (self->state != LEVEE_LOCAL) {
		return false;
	}

	if (lua_type (self->L, -1 - narg) != LUA_TFUNCTION) {
		lua_pushstring (self->L, "lua state is not callable");
		return false;
	}

	if (bg) {
		pthread_attr_t attr;
		if (pthread_attr_init (&attr) != 0) {
			lua_pushfstring (self->L, "failed to initialize pthread attributes: %s", strerror (errno));
			return false;
		}
		if (pthread_attr_setdetachstate (&attr, PTHREAD_CREATE_DETACHED) != 0) {
			lua_pushfstring (self->L, "failed to set pthread attribute: %s", strerror (errno));
			return false;
		}
		self->state = LEVEE_BG;
		self->narg = narg;
		if (pthread_create (&self->thread, &attr, run, self) != 0) {
			self->state = LEVEE_LOCAL;
			lua_pushfstring (self->L, "failed to create pthread: %s", strerror (errno));
			return false;
		}
		return true;
	}

	if (lua_pcall (self->L, narg, 0, 0)) {
		return false;
	}

	return true;
}

bool
levee_runf (Levee *self, lua_CFunction f, int nargs, bool bg)
{
	lua_pushcfunction (self->L, f);
	return levee_run (self, nargs, bg);
}

void
levee_push_number (Levee *self, double num)
{
	if (self->state != LEVEE_LOCAL) return;
	lua_pushnumber (self->L, num);
}

void
levee_push_string (Levee *self, const char *str, size_t len)
{
	if (self->state != LEVEE_LOCAL) return;
	lua_pushlstring (self->L, str, len);
}

void
levee_push_bool (Levee *self, bool val)
{
	if (self->state != LEVEE_LOCAL) return;
	lua_pushboolean (self->L, val);
}

void
levee_push_nil (Levee *self)
{
	if (self->state != LEVEE_LOCAL) return;
	lua_pushnil (self->L);
}

void
levee_push_sender (Levee *self, LeveeChanSender *sender)
{
	if (self->state != LEVEE_LOCAL) return;

	// put ffi module on the stack
	levee_require (self, "ffi"); // stack: ffi

	// get ffi.C.levee_chan_sender_ref
	lua_getfield (self->L, -1, "C"); // stack: ffi C
	lua_getfield (self->L, -2, "gc"); // stack: ffi C gc
	lua_getfield (self->L, -2, "levee_chan_sender_ref"); // stack: ffi C gc ref

	// call ffi.C.levee_chan_sender_ref(sender)
	lua_pushlightuserdata (self->L, sender); // stack: ffi C gc ref sender
	lua_call (self->L, 1, 1); // stack: ffi C gc sender

	// call ffi.gc(sender, ffi.C.levee_chan_sender_unref)
	lua_getfield (self->L, -3, "levee_chan_sender_unref"); // stack: ffi C gc sender unref
	lua_call (self->L, 2, 1); // stack: ffi C sender

	lua_remove (self->L, -2); // stack: ffi sender
	lua_remove (self->L, -2); // stack: sender
}

void
levee_pop (Levee *self, int n)
{
	if (self->state != LEVEE_LOCAL) return;
	lua_pop (self->L, n);
}

void
levee_print_stack (Levee *self, const char *msg)
{
	if (self->state != LEVEE_LOCAL) return;
	fprintf (stderr, "%s: ", msg);
	int i;
	int top = lua_gettop (self->L);
	for (i=1; i<=top; i++) {
		int t = lua_type (self->L, i);
		switch (t) {
			case LUA_TSTRING:
				fprintf (stderr, "\"%s\"", lua_tostring (self->L, i));
				break;
			case LUA_TBOOLEAN:
				fprintf (stderr, lua_toboolean (self->L, i) ? "true" : "false");
				break;
			case LUA_TNUMBER:
				fprintf (stderr, "%g", lua_tonumber (self->L, i));
				break;
			case LUA_TNIL:
				fprintf (stderr, "nil");
				break;
			default:
				lua_getglobal (self->L, "type");
				lua_pushvalue (self->L, i);
				lua_call (self->L, 1, 1);
				fprintf (stderr, "%s", lua_tostring (self->L, -1));
				lua_pop (self->L, 1);
				break;
		}
		fprintf (stderr, "  ");  /* put a separator */
	}
	fprintf (stderr, "\n");  /* end the listing */
}

/*
 * wrapping [f]stat as it's a macro on most systems which can't be directly
 * called from ffi
 */
int
levee_fstat (int fd, struct levee_stat *buf)
{
	struct stat st;
	int rc;

	rc = fstat(fd, &st);
	if (rc < 0) return rc;

	buf->st_size = st.st_size;
	buf->st_mode = st.st_mode;
	return rc;
}

int
levee_stat (const char *path, struct levee_stat *buf)
{
	struct stat st;
	int rc;

	rc = stat(path, &st);
	if (rc < 0) return rc;

	buf->st_size = st.st_size;
	buf->st_mode = st.st_mode;
	return rc;
}

ssize_t
levee_sendfile (int s, int fd, size_t off, size_t len)
{
	ssize_t rc = -1;
#if defined(__APPLE__)

	off_t size = len;
	rc = sendfile (fd, s, off, &size, NULL, 0) < 0 ? -1 : size;

#elif defined(BSD)

	off_t size = len;
	rc = sendfile (fd, s, off, size, NULL, &size, 0) < 0 ? -1 : size;

#elif defined(__linux__)

	off_t offset = off;
	rc = sendfile (s, fd, &offset, len);

#else
# error sendfile not supported
#endif

	return rc;
}
