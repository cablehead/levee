int ioctl(int, unsigned long, ...);

static const unsigned FIOCLEX = 0x20006601;   /* set close on exec on fd */
static const unsigned FIONCLEX = 0x20006602;  /* remove close on exec */
static const unsigned FIONREAD = 0x4004667f;  /* get # bytes to read */
static const unsigned FIONBIO = 0x8004667e;   /* set/clear non-blocking i/o */
static const unsigned FIOASYNC = 0x8004667d;  /* set/clear async i/o */
//static const unsigned FIOSETOWN = 0x8004667c; /* set owner */
//static const unsigned FIOGETOWN = 0x4004667b; /* get owner */
//static const unsigned FIODTYPE = 0x4004667a;  /* get d_type */
