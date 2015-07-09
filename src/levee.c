#include <stdlib.h>
#include <string.h>
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

extern int
luaopen_levee_bundle (lua_State *L);

Levee *
levee_create (void)
{
	lua_State *L = luaL_newstate ();
	if (L == NULL) {
		err (EX_SOFTWARE, "failed to create state");
	}

	luaL_openlibs (L);
	luaopen_levee_bundle (L);

	// put ffi module on the stack
	lua_getglobal (L, "require");
	lua_pushstring (L, "ffi");
	lua_call (L, 1, 1);

	lua_getfield (L, -1, "cdef");
	lua_pushstring (L, levee_cdef);
	lua_call (L, 1, 0);
	lua_pop (L, 1);  // pop ffi module

	lua_getglobal (L, "require");
	lua_pushstring (L, "levee.channel");
	lua_call (L, 1, 1);
	lua_pop (L, 1);

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

void
levee_set_arg (Levee *self, int argc, const char **argv)
{
	assert (self != NULL);

	if (self->state != LEVEE_LOCAL) {
		return;
	}

	lua_createtable (self->L, argc+1, 0);
	lua_pushstring (self->L, "levee");
	lua_rawseti (self->L, -2, -1);
	for (int i = 0; i < argc; i++) {
		lua_pushstring (self->L, argv[i]);
		lua_rawseti (self->L, -2, i);
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
	lua_getglobal (self->L, "require");
	lua_pushstring (self->L, "ffi");
	lua_call (self->L, 1, 1); // stack: ffi

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
 * wrapping fstat as it's a macro on most systems which can't be directly
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
