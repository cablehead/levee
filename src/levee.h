#ifndef LEVEE_H
#define LEVEE_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#include <sys/types.h>
#include <sys/stat.h>

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

#define LEVEE_POLL_MASK    (1ULL << 32) - 1
#define LEVEE_POLL_CHANNEL (1ULL << 32)
#define LEVEE_POLL_SIGNAL  (1ULL << 32) + 1

struct Levee {
	lua_State *L;
	pthread_t thread;
	char *last_error;
	int state;
	int narg;
};

typedef struct {
	lua_CFunction init;
} LeveeConfig;

typedef struct Levee Levee;

extern void
levee_insert_dsym_loader (lua_State *L);

extern void
levee_init (const LeveeConfig *cfg);

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

extern bool
levee_runf (Levee *self, lua_CFunction f, int nargs, bool bg);

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

extern int
levee_require (Levee *self, const char *name);

extern void
levee_set_arg (Levee *self, int argc, const char **argv);

struct levee_stat {
	// unsigned long long  st_dev;       /* Device.  */
	// unsigned long long  st_ino;       /* File serial number.  */
	unsigned int        st_mode;      /* File mode.  */
	// unsigned int        st_nlink;     /* Link count.  */
	// unsigned int        st_uid;       /* User ID of the file's owner.  */
	// unsigned int        st_gid;       /* Group ID of the file's group. */
	// unsigned long long  st_rdev;      /* Device number, if device.  */
	long long           st_size;      /* Size of file, in bytes.  */
	// int                 st_blksize;   /* Optimal block size for I/O.  */
	// long long           st_blocks;    /* Number 512-byte blocks allocated. */
	// struct timespec     st_atime;     /* Time of last access.  */
	// struct timespec     st_mtime;     /* Time of last modification.  */
	// struct timespec     st_ctime;     /* Time of last status change.  */
};

extern int
levee_fstat(int fd, struct levee_stat *buf);

extern int
levee_stat(const char *path, struct levee_stat *buf);

extern ssize_t
levee_sendfile (int s, int fd, size_t off, size_t len);

extern size_t
levee_getcurrentrss ();

#endif
