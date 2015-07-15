
static const int SIGHUP = 1;       /* hangup */
static const int SIGINT = 2;       /* interrupt */
static const int SIGQUIT = 3;      /* quit */
static const int SIGILL = 4;       /* illegal instruction (not reset when
                                      caught) */
static const int SIGTRAP = 5;      /* trace trap (not reset when caught) */
static const int SIGABRT = 6;      /* abort() */
static const int SIGIOT = SIGABRT; /* compatibility */
static const int SIGEMT = 7;       /* EMT instruction */
static const int SIGFPE = 8;       /* floating point exception */
static const int SIGKILL = 9;      /* kill (cannot be caught or ignored) */
static const int SIGBUS = 10;      /* bus error */
static const int SIGSEGV = 11;     /* segmentation violation */
static const int SIGSYS = 12;      /* bad argument to system call */
static const int SIGPIPE = 13;     /* write on a pipe with no one to read it */
static const int SIGALRM = 14;     /* alarm clock */
static const int SIGTERM = 15;     /* software termination signal from kill */
static const int SIGURG = 16;      /* urgent condition on IO channel */
static const int SIGSTOP = 17;     /* sendable stop signal not from tty */
static const int SIGTSTP = 18;     /* stop signal from tty */
static const int SIGCONT = 19;     /* continue a stopped process */
static const int SIGCHLD = 20;     /* to parent on child stop or exit */
static const int SIGTTIN = 21;     /* to readers pgrp upon background tty read
                                    */
static const int SIGTTOU = 22;     /* like TTIN for output if
                                      (tp->t_local&LTOSTOP) */
static const int SIGIO = 23;       /* input/output possible signal */
static const int SIGXCPU = 24;     /* exceeded CPU time limit */
static const int SIGXFSZ = 25;     /* exceeded file size limit */
static const int SIGVTALRM = 26;   /* virtual time alarm */
static const int SIGPROF = 27;     /* profiling time alarm */
static const int SIGWINCH = 28;    /* window size changes */
static const int SIGINFO = 29;     /* information request */
static const int SIGUSR1 = 30;     /* user defined signal 1 */
static const int SIGUSR2 = 31;     /* user defined signal 2 */


typedef void(*sighandler_t)(int);
sighandler_t signal(int signum, sighandler_t handler);
