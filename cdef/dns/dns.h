typedef struct __sFILE FILE;
typedef int dns_error_t;
typedef unsigned long dns_refcount_t;
typedef unsigned long dns_resconf_i_t;
typedef unsigned long dns_atomic_t;

static const int INET6_ADDRSTRLEN	= 46;
static const int DNS_P_DICTSIZE	= 16;
static const int DNS_K_TEA_KEY_SIZE	= 16;
static const int DNS_D_MAXNAME	= 255;

enum dns_section {
	DNS_S_QD		= 0x01,
	DNS_S_AN		= 0x02,
	DNS_S_NS		= 0x04,
	DNS_S_AR		= 0x08,
	DNS_S_ALL		= 0x0f
};

enum dns_class {
	DNS_C_IN	= 1,
	DNS_C_ANY	= 255
};

enum dns_type {
	DNS_T_A		= 1,
	DNS_T_NS	= 2,
	DNS_T_CNAME	= 5,
	DNS_T_SOA	= 6,
	DNS_T_PTR	= 12,
	DNS_T_MX	= 15,
	DNS_T_TXT	= 16,
	DNS_T_AAAA	= 28,
	DNS_T_SRV	= 33,
	DNS_T_OPT	= 41,
	DNS_T_SSHFP	= 44,
	DNS_T_SPF	= 99,
	DNS_T_AXFR      = 252,

	DNS_T_ALL	= 255
};

struct dns_header {
	unsigned qid:16;

/* TODO this assumes little endianness. See src/dns.h */
	unsigned rd:1;
	unsigned tc:1;
	unsigned aa:1;
	unsigned opcode:4;
	unsigned qr:1;

	unsigned rcode:4;
	unsigned unused:3;
	unsigned ra:1;

	unsigned qdcount:16;
	unsigned ancount:16;
	unsigned nscount:16;
	unsigned arcount:16;
};

struct dns_packet {
	unsigned short dict[DNS_P_DICTSIZE];

	struct dns_p_memo {
		struct dns_s_memo {
			unsigned short base, end;
		} qd, an, ns, ar;

		struct {
			unsigned short p;
			unsigned short maxudp;
			unsigned ttl;
		} opt;
	} memo;

	struct { struct dns_packet *cqe_next, *cqe_prev; } cqe;

	size_t size, end;

	int:16; /* tcp padding */

	union {
		struct dns_header header;
		unsigned char data[1];
	};
};

struct dns_options {
	struct {
		void *arg;
		int (*cb)(int *fd, void *arg);
	} closefd;

	/* bitmask for _events() routines */
	enum dns_events {
		DNS_SYSPOLL,
		DNS_LIBEVENT,
	} events;
}; /* struct dns_options */
struct dns_stat {
	size_t queries;

	struct {
		struct {
			size_t count, bytes;
		} sent, rcvd;
	} udp, tcp;
};

struct dns_clock {
	time_t sample, elapsed;
};

struct dns_k_tea {
	uint32_t key[DNS_K_TEA_KEY_SIZE / sizeof (uint32_t)];
	unsigned cycles;
};

struct dns_k_permutor {
	unsigned stepi, length, limit;
	unsigned shift, mask, rounds;

	struct dns_k_tea tea;
};

struct dns_socket {
	struct dns_options opts;

	int udp;
	int tcp;

	int *old;
	unsigned onum, olim;

	int type;

	struct sockaddr_storage local, remote;

	struct dns_k_permutor qids;

	struct dns_stat stat;

	int state;

	unsigned short qid;
	char qname[DNS_D_MAXNAME + 1];
	size_t qlen;
	enum dns_type qtype;
	enum dns_class qclass;

	struct dns_packet *query;
	size_t qout;

	struct dns_clock elapsed;

	struct dns_packet *answer;
	size_t alen, apos;
};

struct dns_rr {
	enum dns_section section;

	struct {
		unsigned short p;
		unsigned short len;
	} dn;

	enum dns_type type;
	enum dns_class class;
	unsigned ttl;

	struct {
		unsigned short p;
		unsigned short len;
	} rd;
};

struct dns_rr_i {
	enum dns_section section;
	const void *name;
	enum dns_type type;
	enum dns_class class;
	const void *data;

	int follow;

	int (*sort)();
	unsigned args[2];

	struct {
		unsigned short next;
		unsigned short count;

		unsigned exec;
		unsigned regs[2];
	} state, saved;
};

struct dns_resolv_conf {
	struct sockaddr_storage nameserver[3];

	char search[4][DNS_D_MAXNAME + 1];

	/* (f)ile, (b)ind, (c)ache */
	char lookup[4 * (1 + (4 * 2))];

	/* getaddrinfo family by preference order ("inet4", "inet6") */
	int family[3];

	struct {
		_Bool edns0;

		unsigned ndots;

		unsigned timeout;

		unsigned attempts;

		_Bool rotate;

		_Bool recurse;

		_Bool smart;

		enum {
			DNS_RESCONF_TCP_ENABLE,
			DNS_RESCONF_TCP_ONLY,
			DNS_RESCONF_TCP_DISABLE,
		} tcp;
	} options;

	struct sockaddr_storage iface;

	struct { /* PRIVATE */
		dns_atomic_t refcount;
	} _;
};

extern const char *dns_strerror(dns_error_t);


extern int levee_dns_p_new(struct dns_packet **, size_t);

extern struct dns_packet * dns_p_init(struct dns_packet *, size_t);

extern struct dns_packet * dns_p_make(size_t, int *);

extern int dns_p_grow(struct dns_packet **);

extern struct dns_packet * dns_p_copy(struct dns_packet *, const struct dns_packet *);

extern enum dns_rcode dns_p_rcode(struct dns_packet *);

extern unsigned dns_p_count(struct dns_packet *, enum dns_section);

extern int dns_p_push(struct dns_packet *, enum dns_section, const void *, size_t, enum dns_type, enum dns_class, unsigned, const void *);

extern void dns_p_dictadd(struct dns_packet *, unsigned short);

extern struct dns_packet * dns_p_merge(struct dns_packet *, enum dns_section, struct dns_packet *, enum dns_section, int *);

extern void dns_p_dump(struct dns_packet *, FILE *);

extern int dns_p_study(struct dns_packet *);



extern char * dns_d_init(void *, size_t, const void *, size_t, int);

extern size_t dns_d_anchor(void *, size_t, const void *, size_t);

extern size_t dns_d_cleave(void *, size_t, const void *, size_t);

extern size_t dns_d_comp(void *, size_t, const void *, size_t, struct dns_packet *, int *);

extern size_t dns_d_expand(void *, size_t, unsigned short, struct dns_packet *, int *);

extern unsigned short dns_d_skip(unsigned short, struct dns_packet *);

extern int dns_d_push(struct dns_packet *, const void *, size_t);

extern size_t dns_d_cname(void *, size_t, const void *, size_t, struct dns_packet *, int *error);



extern int dns_rr_copy(struct dns_packet *, struct dns_rr *, struct dns_packet *);

extern int dns_rr_parse(struct dns_rr *, unsigned short, struct dns_packet *);

extern unsigned short dns_rr_skip(unsigned short, struct dns_packet *);

extern int dns_rr_cmp(struct dns_rr *, struct dns_packet *, struct dns_rr *, struct dns_packet *);

extern size_t dns_rr_print(void *, size_t, struct dns_rr *, struct dns_packet *, int *);


extern int dns_rr_i_packet(struct dns_rr *, struct dns_rr *, struct dns_rr_i *, struct dns_packet *);

extern int dns_rr_i_order(struct dns_rr *, struct dns_rr *, struct dns_rr_i *, struct dns_packet *);

extern int dns_rr_i_shuffle(struct dns_rr *, struct dns_rr *, struct dns_rr_i *, struct dns_packet *);

extern struct dns_rr_i *dns_rr_i_init(struct dns_rr_i *, struct dns_packet *);

extern unsigned dns_rr_grep(struct dns_rr *, unsigned, struct dns_rr_i *, struct dns_packet *, int *);



extern int dns_a_parse(struct dns_a *, struct dns_rr *, struct dns_packet *);

extern int dns_a_push(struct dns_packet *, struct dns_a *);

extern int dns_a_cmp(const struct dns_a *, const struct dns_a *);

extern size_t dns_a_print(void *, size_t, struct dns_a *);

extern size_t dns_a_arpa(void *, size_t, const struct dns_a *);



extern int dns_aaaa_parse(struct dns_aaaa *, struct dns_rr *, struct dns_packet *);

extern int dns_aaaa_push(struct dns_packet *, struct dns_aaaa *);

extern int dns_aaaa_cmp(const struct dns_aaaa *, const struct dns_aaaa *);

extern size_t dns_aaaa_print(void *, size_t, struct dns_aaaa *);

extern size_t dns_aaaa_arpa(void *, size_t, const struct dns_aaaa *);


extern int dns_mx_parse(struct dns_mx *, struct dns_rr *, struct dns_packet *);

extern int dns_mx_push(struct dns_packet *, struct dns_mx *);

extern int dns_mx_cmp(const struct dns_mx *, const struct dns_mx *);

extern size_t dns_mx_print(void *, size_t, struct dns_mx *);

extern size_t dns_mx_cname(void *, size_t, struct dns_mx *);



extern int dns_ns_parse(struct dns_ns *, struct dns_rr *, struct dns_packet *);

extern int dns_ns_push(struct dns_packet *, struct dns_ns *);

extern int dns_ns_cmp(const struct dns_ns *, const struct dns_ns *);

extern size_t dns_ns_print(void *, size_t, struct dns_ns *);

extern size_t dns_ns_cname(void *, size_t, struct dns_ns *);



extern int dns_cname_parse(struct dns_cname *, struct dns_rr *, struct dns_packet *);

extern int dns_cname_push(struct dns_packet *, struct dns_cname *);

extern int dns_cname_cmp(const struct dns_cname *, const struct dns_cname *);

extern size_t dns_cname_print(void *, size_t, struct dns_cname *);

extern size_t dns_cname_cname(void *, size_t, struct dns_cname *);



extern int dns_soa_parse(struct dns_soa *, struct dns_rr *, struct dns_packet *);

extern int dns_soa_push(struct dns_packet *, struct dns_soa *);

extern int dns_soa_cmp(const struct dns_soa *, const struct dns_soa *);

extern size_t dns_soa_print(void *, size_t, struct dns_soa *);



extern int dns_ptr_parse(struct dns_ptr *, struct dns_rr *, struct dns_packet *);

extern int dns_ptr_push(struct dns_packet *, struct dns_ptr *);

extern int dns_ptr_cmp(const struct dns_ptr *, const struct dns_ptr *);

extern size_t dns_ptr_print(void *, size_t, struct dns_ptr *);

extern size_t dns_ptr_cname(void *, size_t, struct dns_ptr *);

extern size_t dns_ptr_qname(void *, size_t, int, void *);



extern int dns_srv_parse(struct dns_srv *, struct dns_rr *, struct dns_packet *);

extern int dns_srv_push(struct dns_packet *, struct dns_srv *);

extern int dns_srv_cmp(const struct dns_srv *, const struct dns_srv *);

extern size_t dns_srv_print(void *, size_t, struct dns_srv *);

extern size_t dns_srv_cname(void *, size_t, struct dns_srv *);



extern struct dns_opt *dns_opt_init(struct dns_opt *, size_t);

extern int dns_opt_parse(struct dns_opt *, struct dns_rr *, struct dns_packet *);

extern int dns_opt_push(struct dns_packet *, struct dns_opt *);

extern int dns_opt_cmp(const struct dns_opt *, const struct dns_opt *);

extern size_t dns_opt_print(void *, size_t, struct dns_opt *);

extern unsigned int dns_opt_ttl(const struct dns_opt *);

extern unsigned short dns_opt_class(const struct dns_opt *);

extern dns_error_t dns_opt_data_push(struct dns_opt *, unsigned char, unsigned short, const void *);



extern int dns_sshfp_parse(struct dns_sshfp *, struct dns_rr *, struct dns_packet *);

extern int dns_sshfp_push(struct dns_packet *, struct dns_sshfp *);

extern int dns_sshfp_cmp(const struct dns_sshfp *, const struct dns_sshfp *);

extern size_t dns_sshfp_print(void *, size_t, struct dns_sshfp *);



extern struct dns_txt *dns_txt_init(struct dns_txt *, size_t);

extern int dns_txt_parse(struct dns_txt *, struct dns_rr *, struct dns_packet *);

extern int dns_txt_push(struct dns_packet *, struct dns_txt *);

extern int dns_txt_cmp(const struct dns_txt *, const struct dns_txt *);

extern size_t dns_txt_print(void *, size_t, struct dns_txt *);



extern union dns_any *dns_any_init(union dns_any *, size_t);

extern int dns_any_parse(union dns_any *, struct dns_rr *, struct dns_packet *);

extern int dns_any_push(struct dns_packet *, union dns_any *, enum dns_type);

extern int dns_any_cmp(const union dns_any *, enum dns_type, const union dns_any *, enum dns_type);

extern size_t dns_any_print(void *, size_t, union dns_any *, enum dns_type);

extern size_t dns_any_cname(void *, size_t, union dns_any *, enum dns_type);



extern struct dns_hosts *dns_hosts_open(int *);

extern void dns_hosts_close(struct dns_hosts *);

extern dns_refcount_t dns_hosts_acquire(struct dns_hosts *);

extern dns_refcount_t dns_hosts_release(struct dns_hosts *);

extern struct dns_hosts *dns_hosts_mortal(struct dns_hosts *);

extern struct dns_hosts *dns_hosts_local(int *);

extern int dns_hosts_loadfile(struct dns_hosts *, FILE *);

extern int dns_hosts_loadpath(struct dns_hosts *, const char *);

extern int dns_hosts_dump(struct dns_hosts *, FILE *);

extern int dns_hosts_insert(struct dns_hosts *, int, const void *, const void *, _Bool);

extern struct dns_packet *dns_hosts_query(struct dns_hosts *, struct dns_packet *, int *);



extern struct dns_resolv_conf *dns_resconf_open(int *);

extern void dns_resconf_close(struct dns_resolv_conf *);

extern dns_refcount_t dns_resconf_acquire(struct dns_resolv_conf *);

extern dns_refcount_t dns_resconf_release(struct dns_resolv_conf *);

extern struct dns_resolv_conf *dns_resconf_mortal(struct dns_resolv_conf *);

extern struct dns_resolv_conf *dns_resconf_local(int *);

extern struct dns_resolv_conf *dns_resconf_root(int *);

extern int dns_resconf_pton(struct sockaddr_storage *, const char *);

extern int dns_resconf_loadfile(struct dns_resolv_conf *, FILE *);

extern int dns_resconf_loadpath(struct dns_resolv_conf *, const char *);

extern int dns_nssconf_loadfile(struct dns_resolv_conf *, FILE *);

extern int dns_nssconf_loadpath(struct dns_resolv_conf *, const char *);

extern int dns_resconf_dump(struct dns_resolv_conf *, FILE *);

extern int dns_nssconf_dump(struct dns_resolv_conf *, FILE *);

extern int dns_resconf_setiface(struct dns_resolv_conf *, const char *, unsigned short);

extern size_t dns_resconf_search(void *, size_t, const void *, size_t, struct dns_resolv_conf *, dns_resconf_i_t *);



extern struct dns_hints *dns_hints_open(struct dns_resolv_conf *, int *);

extern void dns_hints_close(struct dns_hints *);

extern dns_refcount_t dns_hints_acquire(struct dns_hints *);

extern dns_refcount_t dns_hints_release(struct dns_hints *);

extern struct dns_hints *dns_hints_mortal(struct dns_hints *);

extern int dns_hints_insert(struct dns_hints *, const char *, const struct sockaddr *, unsigned);

extern unsigned dns_hints_insert_resconf(struct dns_hints *, const char *, const struct dns_resolv_conf *, int *);

extern struct dns_hints *dns_hints_local(struct dns_resolv_conf *, int *);

extern struct dns_hints *dns_hints_root(struct dns_resolv_conf *, int *);

extern struct dns_packet *dns_hints_query(struct dns_hints *, struct dns_packet *, int *);

extern int dns_hints_dump(struct dns_hints *, FILE *);


extern unsigned dns_hints_grep(struct sockaddr **, socklen_t *, unsigned, struct dns_hints_i *, struct dns_hints *);



extern struct dns_cache *dns_cache_init(struct dns_cache *);

extern void dns_cache_close(struct dns_cache *);



extern struct dns_socket *dns_so_open(const struct sockaddr *, int, const struct dns_options *, int *error);

extern struct dns_socket *levee_dns_so_open(int fd, const struct sockaddr *, int, const struct dns_options *, int *error);

extern void dns_so_close(struct dns_socket *);

extern void dns_so_reset(struct dns_socket *);

extern unsigned short dns_so_mkqid(struct dns_socket *so);

extern struct dns_packet *dns_so_query(struct dns_socket *, struct dns_packet *, struct sockaddr *, int *);

extern int dns_so_submit(struct dns_socket *, struct dns_packet *, struct sockaddr *);

extern int dns_so_check(struct dns_socket *);

extern struct dns_packet *dns_so_fetch(struct dns_socket *, int *);

extern time_t dns_so_elapsed(struct dns_socket *);

extern void dns_so_clear(struct dns_socket *);

extern int dns_so_events(struct dns_socket *);

extern int dns_so_pollfd(struct dns_socket *);

extern int dns_so_poll(struct dns_socket *, int);

extern const struct dns_stat *dns_so_stat(struct dns_socket *);



extern struct dns_resolver *dns_res_open(struct dns_resolv_conf *, struct dns_hosts *hosts, struct dns_hints *, struct dns_cache *, const struct dns_options *, int *);

extern struct dns_resolver *dns_res_stub(const struct dns_options *, int *);

extern void dns_res_reset(struct dns_resolver *);

extern void dns_res_close(struct dns_resolver *);

extern dns_refcount_t dns_res_acquire(struct dns_resolver *);

extern dns_refcount_t dns_res_release(struct dns_resolver *);

extern struct dns_resolver *dns_res_mortal(struct dns_resolver *);

extern int dns_res_submit(struct dns_resolver *, const char *, enum dns_type, enum dns_class);

extern int dns_res_submit2(struct dns_resolver *, const char *, size_t, enum dns_type, enum dns_class);

extern int dns_res_check(struct dns_resolver *);

extern struct dns_packet *dns_res_fetch(struct dns_resolver *, int *);

extern time_t dns_res_elapsed(struct dns_resolver *);

extern void dns_res_clear(struct dns_resolver *);

extern int dns_res_events(struct dns_resolver *);

extern int dns_res_pollfd(struct dns_resolver *);

extern time_t dns_res_timeout(struct dns_resolver *);

extern int dns_res_poll(struct dns_resolver *, int);

extern struct dns_packet *dns_res_query(struct dns_resolver *, const char *, enum dns_type, enum dns_class, int, int *);

extern const struct dns_stat *dns_res_stat(struct dns_resolver *);

extern void dns_res_sethints(struct dns_resolver *, struct dns_hints *);



extern struct dns_addrinfo *dns_ai_open(const char *, const char *, enum dns_type, const struct addrinfo *, struct dns_resolver *, int *);

extern void dns_ai_close(struct dns_addrinfo *);

extern int dns_ai_nextent(struct addrinfo **, struct dns_addrinfo *);

extern size_t dns_ai_print(void *, size_t, struct addrinfo *, struct dns_addrinfo *);

extern time_t dns_ai_elapsed(struct dns_addrinfo *);

extern void dns_ai_clear(struct dns_addrinfo *);

extern int dns_ai_events(struct dns_addrinfo *);

extern int dns_ai_pollfd(struct dns_addrinfo *);

extern time_t dns_ai_timeout(struct dns_addrinfo *);

extern int dns_ai_poll(struct dns_addrinfo *, int);

extern const struct dns_stat *dns_ai_stat(struct dns_addrinfo *);



extern size_t dns_strlcpy(char *, const char *, size_t);

extern size_t dns_strlcat(char *, const char *, size_t);
