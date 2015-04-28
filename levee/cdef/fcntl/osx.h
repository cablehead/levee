int fcntl(int fd, int cmd, ... /* arg */);

static const int F_DUPFD = 0; /* Duplicate file descriptor.  */
static const int F_GETFD = 1; /* Get file descriptor flags.  */
static const int F_SETFD = 2; /* Set file descriptor flags.  */
static const int F_GETFL = 3; /* Get file status flags.  */
static const int F_SETFL = 4; /* Set file status flags.  */

static const int O_ACCMODE =      0003;
static const int O_RDONLY =         00;
static const int O_WRONLY =         01;
static const int O_RDWR =           02;

static const int O_CREAT     = 0x0200;
static const int O_EXCL		   = 0x0800;
static const int O_NOCTTY    = 0x20000;
static const int O_TRUNC	   = 0x0400;
static const int O_APPEND	   = 0x0008;
static const int O_NONBLOCK	 = 0x0004;

static const int O_NDELAY = O_NONBLOCK;
