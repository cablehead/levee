#ifndef LEVEE_H
#define LEVEE_H

#include <stdint.h>
#include <stdbool.h>
#include <sys/types.h>
#include <stddef.h>

#ifdef __linux__
# include <sys/epoll.h>
# include <sys/eventfd.h>
# define LEVEE_EPOLL
#else
# include <sys/event.h>
# define LEVEE_KQUEUE
#endif

#define len(arr) (sizeof (arr) / sizeof ((arr)[0]))

#define container_of(ptr, type, member) __extension__ ({   \
	const __typeof( ((type *)0)->member ) *__mptr = (ptr); \
	(type *)( (char *)__mptr - offsetof(type,member) );    \
})

#include "chan.h"
#include "lua.h"

struct Levee {
	lua_State *L;
	pthread_t thread;
	char *last_error;
	int state;
	int narg;
};

typedef struct Levee Levee;

extern Levee *
levee_create (void);

extern void
levee_destroy (Levee *self);

extern void
levee_report_error (Levee *self);

extern bool
levee_load_file (Levee *self, const char *path);

extern bool
levee_load_string (Levee *self, const char *script, size_t len, const char *name);

extern bool
levee_run (Levee *self, int nargs, bool bg);

extern void
levee_push_number (Levee *self, double num);

extern void
levee_push_string (Levee *self, const char *str, size_t len);

extern void
levee_push_bool (Levee *self, bool val);

extern void
levee_push_nil (Levee *self);

extern void
levee_push_sender (Levee *self, LeveeChanSender *sender);

extern void
levee_pop (Levee *self, int n);

extern void
levee_print_stack (Levee *self, const char *msg);

extern const char *
levee_get_error (Levee *self);

extern void
levee_set_arg (Levee *self, int argc, const char **argv);

#endif

