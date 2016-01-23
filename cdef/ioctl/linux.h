int ioctl(int, int, ...);

static const unsigned FIOCLEX = 0x5451;   /* set close on exec on fd */
static const unsigned FIONCLEX = 0x5450;  /* remove close on exec */
static const unsigned FIONREAD = 0x541b;  /* get # bytes to read */
static const unsigned FIONBIO = 0x5421;   /* set/clear non-blocking i/o */
static const unsigned FIOASYNC = 0x5452;  /* set/clear async i/o */

static const unsigned TIOCGWINSZ = 0x5413;
