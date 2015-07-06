typedef void(*sighandler_t)(int);
sighandler_t signal(int signum, sighandler_t handler);
