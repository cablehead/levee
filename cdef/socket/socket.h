typedef unsigned int socklen_t;
typedef unsigned short int in_port_t;
typedef unsigned int in_addr_t;

struct in_addr {
	in_addr_t s_addr;
};

struct in6_addr {
	union {
		uint8_t   __u6_addr8[16];
		uint16_t  __u6_addr16[8];
		uint32_t  __u6_addr32[4];
	} __in6_u;
};

struct iovec {
	char   *iov_base;
	size_t iov_len;
};

static const int INADDR_ANY = 0x00000000;
static const int SOMAXCONN = 128;

static const int PF_UNSPEC = 0;
static const int PF_LOCAL = 1;
static const int PF_UNIX = PF_LOCAL;
static const int PF_FILE = PF_LOCAL;
static const int PF_INET = 2;

static const int AF_UNSPEC = PF_UNSPEC;
static const int AF_LOCAL = PF_LOCAL;
static const int AF_UNIX = PF_UNIX;
static const int AF_FILE = PF_FILE;
static const int AF_INET = PF_INET;

static const int SOCK_STREAM = 1;
static const int SOCK_DGRAM = 2;

int socket(int domain, int type, int protocol);

int getsockopt(int sockfd, int level, int optname, void *optval, socklen_t *optlen);
int setsockopt(int sockfd, int level, int optname, const void *optval, socklen_t optlen);

uint16_t htons(uint16_t hostshort);
uint16_t ntohs(uint16_t netshort);
int inet_aton(const char *cp, struct in_addr *inp);
const char *inet_ntop(int af, const void * restrict src, char * restrict dst, socklen_t size);

int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen);

int listen(int sockfd, int backlog);

int accept(int sockfd, struct sockaddr *addr, socklen_t *addrlen);

int connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen);

ssize_t read(int fd, void *buf, size_t count);
ssize_t readv(int d, const struct iovec *iov, int iovcnt);

ssize_t recvfrom(
	int socket, void * restrict buffer, size_t length, int flags,
	struct sockaddr * restrict src_addr, socklen_t * restrict src_addrlen);

ssize_t sendto(
	int socket, const void *buffer, size_t length, int flags,
	const struct sockaddr *dest_addr, socklen_t dest_len);

ssize_t write(int fd, const void *buf, size_t count);
ssize_t writev(int fildes, const struct iovec *iov, int iovcnt);

int close(int fd);

int getsockname(int socket, struct sockaddr *address, socklen_t *address_len);
int getpeername(int socket, struct sockaddr *address, socklen_t *address_len);

