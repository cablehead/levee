void *malloc(size_t);
void free(void *);
void memcpy(void *restrict, const void *restrict, size_t);
void memmove(void *restrict, const void *restrict, size_t);
int pipe(int pipefd[2]);
int open(const char *path, int oflag, ...);

int getpid(void);
int kill(int pid, int sig);
