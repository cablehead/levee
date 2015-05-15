static const int PF_INET6 = 10;
static const int AF_INET6 = PF_INET6;

static const int SOL_SOCKET    = 1;
static const int SO_REUSEADDR  = 2;
static const int SO_ACCEPTCONN = 30;

typedef uint16_t sa_family_t;

struct sockaddr {
	sa_family_t sin_family;
	char sa_data[14];
};

struct sockaddr_storage {
    sa_family_t ss_family;
    uint64_t __ss_align;
    char __ss_padding[128 - (2 * sizeof (uint64_t))];
};

struct sockaddr_in {
	sa_family_t sin_family;
	in_port_t sin_port;
	struct in_addr sin_addr;
	uint8_t sin_zero[sizeof(struct sockaddr) -
		sizeof(sa_family_t) -
		sizeof(in_port_t) -
		sizeof(struct in_addr)];
};

struct sockaddr_in6 {
	sa_family_t sin6_family;
	in_port_t sin6_port;
	uint32_t sin6_flowinfo;
	struct in6_addr sin6_addr;
	uint32_t sin6_scope_id;
};

struct sockaddr_un {
	sa_family_t sun_family;
	char sun_path[108];
};
