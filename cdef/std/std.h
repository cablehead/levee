void *malloc(size_t);
void free(void *);
void memcpy(void *restrict, const void *restrict, size_t);
void memmove(void *restrict, const void *restrict, size_t);


static const int STDIN = 0;
static const int STDOUT = 1;
static const int STDERR = 2;
static const int CAPTURE = -10;

int pipe(int pipefd[2]);
int open(const char *path, int oflag, ...);
int dup2(int fd1, int fd2);
