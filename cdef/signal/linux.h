typedef struct {
	unsigned long int data[16];
} sigset_t;

int signalfd(int fd, const sigset_t *mask, int flags);
int sigaddset(sigset_t *set, int signum);
int sigismember(const sigset_t *set, int signum);
int sigprocmask(int how, const sigset_t *set, sigset_t *oldset);

static const int SIG_BLOCK    = 0;
static const int SIG_UNBLOCK  = 1;
static const int SIG_SETMASK  = 2;
