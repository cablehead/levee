#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <err.h>
#include <sysexits.h>
#include <errno.h>
#include <assert.h>
#include <pthread.h>
#include <signal.h>
#include <sys/socket.h>
#include <inttypes.h>
#include <unistd.h>

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
static Levee *main_state = NULL;

extern int
luaopen_levee (lua_State *L);

extern int
luaopen_lpeg (lua_State *L);

typedef struct {
	char *p;
	char buf[4096];
} Msg;

static void
msg_init (Msg *m)
{
	m->p = m->buf;
}

static ssize_t
msg_write (Msg *m, int fd)
{
	return write (fd, m->buf, m->p - m->buf);
}

static bool
msg_append (Msg *m, const char *val, size_t len, int pad, char fill)
{
	size_t remain = sizeof (m->buf) - (m->p - m->buf), npad = 0;
	if (pad < 0 && (size_t)-pad > len) { npad = (size_t)-pad - len; }
	else if (pad > 0 && (size_t)pad > len) { npad = (size_t)pad - len; }

	if (len + npad > remain) { return false; }

	if (npad > 0 && pad > 0) {
		memset (m->p, fill, npad);
		m->p += npad;
	}
	memcpy (m->p, val, len);
	m->p += len;
	if (npad > 0 && pad < 0) {
		memset (m->p, fill, npad);
		m->p += npad;
	}
	return true;
}

#define msg_append_arr(m, arr, pad, fill) \
	msg_append ((m), (arr), sizeof (arr) - 1, (pad), (fill))

static bool
msg_append_str (Msg *m, const char *str, int pad, char fill)
{
	return msg_append (m, str, strlen (str), pad, fill);
}

static bool
msg_append_int (Msg *m, intptr_t val, size_t base, int pad, char fill)
{
	if (base < 2 || base > 16 || val == INTPTR_MIN) { return false; }
	intptr_t n = val < 0 ? -val : val;
	char buf[256], *p = buf + sizeof(buf);
	for (; n > 0; n /= base) { *--p = "0123456789abcdef"[n % base]; }
	if (p == buf + sizeof(buf)) { *--p = '0'; }
    if (val < 0) { *--p = '-'; }
	return msg_append (m, p, sizeof (buf) - (p - buf), pad, fill);
}

static void
handle_fault (int sig, siginfo_t *si, void *ptr)
{
	Msg msg;
	msg_init (&msg);
	msg_append_arr (&msg, "recieved fault at address 0x", 0, 0);
	msg_append_int (&msg, (intptr_t)si->si_addr, 16, 12, '0');
	msg_append_arr (&msg, ":\n", 0, 0);

	if (main_state) {
		lua_State *L = main_state->L;
		lua_Debug ar[32];
		int count;
		size_t maxlen = 0;
		for (count = 0; count < 32; count++) {
			if (lua_getstack (L, count+1, &ar[count]) != 1) { break; }
			if (lua_getinfo( L, "nSl", &ar[count]) == 0) { break; }
			if (strcmp (ar[count].what, "C") != 0) {
				ssize_t len = strlen (ar[count].short_src);

				// try to shorten the source path
				const char *start = strstr (ar[count].short_src, "levee/levee/");
				if (start) {
					start += 6;
					len -= start - ar[count].short_src;
					memmove(ar[count].short_src, start, len+1);
				}

				if (len > maxlen) { maxlen = len; }
			}
		}

		// add space for line number
		maxlen += 8;

		for (int i = 0; i < count; i++) {
			msg_append_arr (&msg, "  ", 0, 0);
			if (strcmp (ar[i].what, "C") == 0) {
				msg_append_arr (&msg, "[C] ", 0, 0);
				msg_append_arr (&msg, " ", (int)(maxlen - 3), ' ');
				msg_append_str (&msg, ar[i].name ? ar[i].name : "-", 0, 0);
			}
			else {
				msg_append_str (&msg, ar[i].short_src, 0, 0);
				msg_append_arr (&msg, ":", 0, 0);
				msg_append_int (&msg, ar[i].currentline, 10,
						-(int)(maxlen - strlen(ar[i].short_src)), ' ');
				if (ar[i].name == NULL) {
					msg_append_arr (&msg, "anonymous@", 0, 0);
					msg_append_int (&msg, ar[i].linedefined, 10, 0, 0);
				}
				else {
					msg_append_str (&msg, ar[i].name, 0, 0);
				}
			}
			msg_append_str (&msg, "\n", 0, 0);
		}
	}

	msg_write (&msg, STDERR_FILENO);

	abort ();
}

static int
require (lua_State *L, const char *name)
{
	lua_getglobal (L, "require");
	lua_pushstring (L, name);
	lua_call (L, 1, 1);
	return 1;
}

static void
print_value (lua_State *L, int idx, int indent)
{
#define MAX_INDENT 8
	static const char space[MAX_INDENT*2] = "                ";

	if (indent > 0) {
		if (indent > MAX_INDENT) { indent = MAX_INDENT; }
		fwrite (space, 1, indent*2, stderr);
	}

	if (idx < 0) {
		idx = lua_gettop (L) + idx + 1;
		if (idx < 0) {
			fprintf (stderr, "#");
			return;
		}
	}

	int t = lua_type (L, idx);
	switch (t) {
	case LUA_TSTRING:
		fprintf (stderr, "\"%s\"", lua_tostring (L, idx));
		return;
	case LUA_TBOOLEAN:
		fprintf (stderr, lua_toboolean (L, idx) ? "true" : "false");
		return;
	case LUA_TNUMBER:
		fprintf (stderr, "%g", lua_tonumber (L, idx));
		return;
	case LUA_TNIL:
		fprintf (stderr, "nil");
		return;
	case LUA_TFUNCTION: {
		const void *func = (const void *)lua_tocfunction (L, idx);
		Dl_info info;
		if (func != NULL && dladdr (func, &info) > 0) {
			fprintf (stderr, "%s", info.dli_sname);
			return;
		}
		break;
	}
	case LUA_TTABLE:
		if (indent > -1 && indent < MAX_INDENT) {
			fprintf (stderr, "{\n");
			lua_pushnil (L);
			while (lua_next (L, idx)) {
				print_value (L, -2, indent+1);
				fprintf (stderr, " = ");
				print_value (L, -1, -1);
				fprintf (stderr, ",\n");
				lua_pop (L, 1);
			}
			fprintf (stderr, " }");
			return;
		}
		break;
	}

	lua_getglobal (L, "type");
	lua_pushvalue (L, idx);
	lua_call (L, 1, 1);
	fprintf (stderr, "%s", lua_tostring (L, -1));
	lua_pop (L, 1);
}

static void
print_stack (lua_State *L, const char *msg, bool expand_table)
{
	fprintf (stderr, "%s: ", msg);
	int i;
	int top = lua_gettop (L);
	for (i=1; i<=top; i++) {
		print_value (L, i, expand_table ? 0 : -1);
		fprintf (stderr, "  ");
	}
	fprintf (stderr, "\n");
}

static int
levee_dsym_loader (lua_State *L)
{
	size_t len;
	const char *target = lua_tolstring (L, 1, &len);
	const char *offset = strchr (target, '.');
	if (offset != NULL) { len = offset - target; }

	static const char prefix[] = "luaopen_";
	size_t symsize = len + sizeof (prefix);
	char sym[symsize];
	snprintf (sym, symsize, "luaopen_%.*s", (int) len, target);

	union {
		void *v;
		lua_CFunction f;
	} fsym;
	fsym.v = dlsym (RTLD_DEFAULT, sym);

	if (fsym.v != NULL) {
		int n;
		n = fsym.f (L);
		lua_pop(L, n);  // remove anything that luaopen may have put on the stack

		lua_getfield (L, LUA_REGISTRYINDEX, "_PRELOAD");
		lua_getfield (L, -1, target);
		lua_remove (L, 2);  // remove _PRELOAD

		if (lua_type(L, -1) == LUA_TFUNCTION) {
			// luaopen placed a callable in the PRELOAD table, use that
			return 1;
		}

		lua_pop(L, 1);  // remove the PRELOAD table entry

		if (n > 0) {
			// the luaopen appears to return the module contents
			lua_pushcfunction(L, fsym.f);
			return 1;
		}

		// give up
		return 0;
	}

	char msg[symsize + 20];
	snprintf (msg, sizeof(msg), "\tno symbol: %s", sym);
	lua_pushstring (L, msg);
	return 1;
}

void
insert_dsym_loader (lua_State *L)
{
	lua_getglobal (L, "table");
	lua_getfield (L, -1, "insert");
	lua_remove (L, -2);  // remove table

	lua_getglobal (L, "package");
	lua_getfield (L, -1, "loaders");
	lua_remove (L, -2);  // remove package

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

	Levee *self = malloc (sizeof *self);
	if (self == NULL) {
		int err = errno;
		lua_close (L);
		errno = err;
		return NULL;
	}

	insert_dsym_loader (L);

	__sync_synchronize ();
	const LeveeConfig *cfg = config;
	if (cfg != NULL && cfg->init != NULL) {
		cfg->init (L);
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

	lua_createtable (self->L, argc, 0);
	lua_pushstring (self->L, argv[0]);
	lua_rawseti (self->L, -2, 0);
	for (int i = 1; i < argc; i++) {
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
	sigset_t set;
	sigfillset (&set);
	pthread_sigmask (SIG_SETMASK, &set, NULL);

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
	else {
		main_state = self;

		struct sigaction sa;
		sa.sa_flags = SA_SIGINFO;
		sigemptyset (&sa.sa_mask);
		sa.sa_sigaction = handle_fault;
		sigaction (SIGSEGV, &sa, NULL);
		sigaction (SIGBUS, &sa, NULL);
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
	print_stack (self->L, msg, false);
}

ssize_t
levee_sendfile (int s, int fd, size_t off, size_t len)
{
	ssize_t rc = -1;
#if defined(__APPLE__)

	off_t size = len;
	rc = sendfile (fd, s, off, &size, NULL, 0);
	if (size > 0) {
		rc = size;
	}

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


/**
 * http://stackoverflow.com/a/14927379
 * Returns the current resident set size (physical memory use) measured
 * in bytes, or zero if the value cannot be determined on this OS.
 */
#if defined(_WIN32)
#include <windows.h>
#include <psapi.h>

#elif defined(__unix__) || defined(__unix) || defined(unix) || (defined(__APPLE__) && defined(__MACH__))
#include <unistd.h>
#include <sys/resource.h>

#if defined(__APPLE__) && defined(__MACH__)
#include <mach/mach.h>

#elif (defined(_AIX) || defined(__TOS__AIX__)) || (defined(__sun__) || defined(__sun) || defined(sun) && (defined(__SVR4) || defined(__svr4__)))
#include <fcntl.h>
#include <procfs.h>

#elif defined(__linux__) || defined(__linux) || defined(linux) || defined(__gnu_linux__)
#include <stdio.h>
#endif
#else
#error "Cannot define getPeakRSS( ) or getCurrentRSS( ) for an unknown OS."
#endif

size_t levee_getcurrentrss ()
{
#if defined(_WIN32)
		/* Windows -------------------------------------------------- */
		PROCESS_MEMORY_COUNTERS info;
		GetProcessMemoryInfo( GetCurrentProcess( ), &info, sizeof(info) );
		return (size_t)info.WorkingSetSize;

#elif defined(__APPLE__) && defined(__MACH__)
		/* OSX ------------------------------------------------------ */
		struct mach_task_basic_info info;
		mach_msg_type_number_t infoCount = MACH_TASK_BASIC_INFO_COUNT;
		if ( task_info( mach_task_self( ), MACH_TASK_BASIC_INFO,
				(task_info_t)&info, &infoCount ) != KERN_SUCCESS )
				return (size_t)0L;			/* Can't access? */
		return (size_t)info.resident_size;

#elif defined(__linux__) || defined(__linux) || defined(linux) || defined(__gnu_linux__)
		/* Linux ---------------------------------------------------- */
		long rss = 0L;
		FILE* fp = NULL;
		if ( (fp = fopen( "/proc/self/statm", "r" )) == NULL )
				return (size_t)0L;			/* Can't open? */
		if ( fscanf( fp, "%*s%ld", &rss ) != 1 )
		{
				fclose( fp );
				return (size_t)0L;			/* Can't read? */
		}
		fclose( fp );
		return (size_t)rss * (size_t)sysconf( _SC_PAGESIZE);

#else
		/* AIX, BSD, Solaris, and Unknown OS ------------------------ */
		return (size_t)0L;					/* Unsupported. */
#endif
}
