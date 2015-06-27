#ifndef LEVEE_H
#define LEVEE_H

#include <stdint.h>
#include <stdbool.h>
#include <sys/types.h>

#ifdef __linux__
# include <sys/epoll.h>
# include <sys/event.h>
# define LEVEE_EPOLL
#else
# include <sys/event.h>
# define LEVEE_KQUEUE
#endif

typedef struct Levee Levee;

extern Levee *
levee_create (void);

extern void
levee_destroy (Levee *self);

extern int
levee_load_file (Levee *self, const char *path);

extern int
levee_load_script (Levee *self, const char *script, size_t len, const char *name);

extern void
levee_set_arg (Levee *self, int argc, const char **argv);

extern int
levee_run (Levee *self, bool bg);

#endif

