static const int PF_INET6 = 30;
static const int AF_INET6 = PF_INET6;

static const int SOL_SOCKET    = 0xffff;
static const int SO_REUSEADDR  = 0x0004;
static const int SO_ACCEPTCONN = 0x0002;

static const int NI_NOFQDN      = 0x00000001;
static const int NI_NUMERICHOST = 0x00000002;
static const int NI_NAMEREQD    = 0x00000004;
static const int NI_NUMERICSERV = 0x00000008;
static const int NI_DGRAM       = 0x00000010;

typedef uint8_t sa_family_t;

struct sockaddr {
	uint8_t sa_len;
	sa_family_t sa_family;
	char sa_data[14];
};

struct sockaddr_storage {
	uint8_t ss_len;
	sa_family_t ss_family;
	char __ss_pad1[sizeof(int64_t) - sizeof(uint8_t) - sizeof(sa_family_t)];
	int64_t __ss_align;
	char __ss_pad2[128 -
		sizeof(uint8_t) -
		sizeof(sa_family_t) - 
		(sizeof(int64_t) - sizeof(uint8_t) - sizeof(sa_family_t)) -
		sizeof(int64_t)];
};

struct sockaddr_in {
	uint8_t sin_len;
	sa_family_t sin_family;
	in_port_t sin_port;
	struct in_addr sin_addr;
	char sin_zero[8];
};

struct sockaddr_in6 {
	uint8_t sin6_len;
	sa_family_t sin6_family;
	in_port_t sin6_port;
	uint32_t sin6_flowinfo;
	struct in6_addr sin6_addr;
	uint32_t sin6_scope_id;
};

struct sockaddr_un {
	uint8_t sun_len;
	sa_family_t sun_family;
	char sun_path[104];
};

struct addrinfo {
	int     ai_flags;       /* AI_PASSIVE, AI_CANONNAME, AI_NUMERICHOST */
	int     ai_family;      /* PF_xxx */
	int     ai_socktype;    /* SOCK_xxx */
	int     ai_protocol;    /* 0 or IPPROTO_xxx for IPv4 and IPv6 */
	socklen_t ai_addrlen;   /* length of ai_addr */
	char    *ai_canonname;  /* canonical name for hostname */
	struct  sockaddr *ai_addr;      /* binary address */
	struct  addrinfo *ai_next;      /* next structure in linked list */
};
