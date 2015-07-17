int getpid(void);
int getppid(void);
int kill(int pid, int sig);
int fork(void);

static const int WNOHANG = 1;

int waitpid(int pid, int *stat_loc, int options);

int execv(const char *path, const char *argv[]);
int execvp(const char *name, const char *argv[]);
int execve(const char *path, const char *argv[], const char *envp[]);

int execl(const char *path, const char *arg0, ... /*, (char *)0 */);
int execlp(const char *file, const char *arg0, ... /*, (char *)0 */);
int execle(const char *path, const char *arg0, ...
           /*, (char *)0, char *const envp[] */);
