typedef unsigned int sigset_t;

void *malloc(size_t);
void free(void *);
void memcpy(void *restrict, const void *restrict, size_t);
void memmove(void *restrict, const void *restrict, size_t);
int pipe(int pipefd[2]);
