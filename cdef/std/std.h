void *malloc(size_t);
void *realloc(void *ptr, size_t size);

void free(void *);
void memcpy(void *restrict, const void *restrict, size_t);
void memmove(void *restrict, const void *restrict, size_t);
void *memset(void *b, int c, size_t len);
int getpagesize(void);


static const int STDIN = 0;
static const int STDOUT = 1;
static const int STDERR = 2;
static const int CAPTURE = -10;

int pipe(int pipefd[2]);
int open(const char *path, int oflag, ...);
int dup2(int fd1, int fd2);


static const int F_OK = 0;
int access(const char *path, int amode);

int chdir(const char *path);
char *getcwd(char *buf, size_t size);
char *realpath(const char *restrict n, char *restrict r);

void abort (void);

unsigned int sleep(unsigned int seconds);
int usleep(unsigned int useconds);

int dirfd(void *);

struct servent {
	char    *s_name;        /* official name of service */
	char    **s_aliases;    /* alias list */
	int     s_port;         /* port service resides at */
	char    *s_proto;       /* protocol to use */
};

struct servent* getservbyname(const char *name, const char *proto);
