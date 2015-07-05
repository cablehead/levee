enum {
	EPOLLIN      = 0x001,
	EPOLLPRI     = 0x002,
	EPOLLOUT     = 0x004,
	EPOLLRDNORM  = 0x040,
	EPOLLRDBAND  = 0x080,
	EPOLLWRNORM  = 0x100,
	EPOLLWRBAND  = 0x200,
	EPOLLMSG     = 0x400,
	EPOLLERR     = 0x008,
	EPOLLHUP     = 0x010,
	EPOLLRDHUP   = 0x2000,
	EPOLLWAKEUP  = 0x20000000,
	EPOLLONESHOT = 0x40000000,
	EPOLLET      = 0x80000000
};

static const int EPOLL_CTL_ADD = 1;
static const int EPOLL_CTL_DEL = 2;
static const int EPOLL_CTL_MOD = 3;

typedef union epoll_data {
	void *ptr;
	int fd;
	uint32_t u32;
	uint64_t u64;
} epoll_data_t;

struct epoll_event {
	uint32_t events;
	epoll_data_t data;
} __attribute__((packed));

extern int epoll_create1(int flags);
extern int epoll_ctl(int epfd, int op, int fd, struct epoll_event *ev);
extern int epoll_wait(int epfd, struct epoll_event *events, int maxevents,
		int timeout);
extern int epoll_pwait(int epfd, struct epoll_event *events, int maxevents,
		int timeout, const sigset_t *ss);



enum {
	EFD_SEMAPHORE = 00000001,
	EFD_CLOEXEC = 02000000,
	EFD_NONBLOCK = 00004000
};

typedef uint64_t eventfd_t;

extern int eventfd(int count, int flags);
extern int eventfd_read(int fd, eventfd_t *value);
extern int eventfd_write(int fd, eventfd_t value);



enum {
	SFD_CLOEXEC = 02000000,
	SFD_NONBLOCK = 00004000
};
