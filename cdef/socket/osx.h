static const int PF_INET6 = 30;
static const int AF_INET6 = PF_INET6;

static const int SOL_SOCKET    = 0xffff;
static const int SO_REUSEADDR  = 0x0004;
static const int SO_ACCEPTCONN = 0x0002;

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
