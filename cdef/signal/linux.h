static const int SIGHUP     =  1;
static const int SIGINT     =  2;
static const int SIGQUIT    =  3;
static const int SIGILL     =  4;
static const int SIGTRAP    =  5;
static const int SIGABRT    =  6;
static const int SIGIOT     =  6;
static const int SIGBUS     =  7;
static const int SIGFPE     =  8;
static const int SIGKILL    =  9;
static const int SIGUSR1    = 10;
static const int SIGSEGV    = 11;
static const int SIGUSR2    = 12;
static const int SIGPIPE    = 13;
static const int SIGALRM    = 14;
static const int SIGTERM    = 15;
static const int SIGSTKFLT  = 16;
static const int SIGCHLD    = 17;
static const int SIGCONT    = 18;
static const int SIGSTOP    = 19;
static const int SIGTSTP    = 20;
static const int SIGTTIN    = 21;
static const int SIGTTOU    = 22;
static const int SIGURG     = 23;
static const int SIGXCPU    = 24;
static const int SIGXFSZ    = 25;
static const int SIGVTALRM  = 26;
static const int SIGPROF    = 27;
static const int SIGWINCH   = 28;
static const int SIGIO      = 29;
static const int SIGPOLL    = SIGIO;
static const int SIGPWR     = 30;
static const int SIGSYS     = 31;
static const int SIGUNUSED  = 31;


typedef struct {
	unsigned long int data[16];
} sigset_t;

int sigaddset(sigset_t *set, int signum);
int sigismember(const sigset_t *set, int signum);
int sigprocmask(int how, const sigset_t *set, sigset_t *oldset);

int signalfd(int fd, const sigset_t *mask, int flags);


static const int SIG_BLOCK    = 0;
static const int SIG_UNBLOCK  = 1;
static const int SIG_SETMASK  = 2;
