struct winsize {
  unsigned short ws_row;
  unsigned short ws_col;
  unsigned short ws_xpixel;
  unsigned short ws_ypixel;
};

typedef unsigned char cc_t;
typedef unsigned long tcflag_t;
typedef unsigned long speed_t;

static const int TCSAFLUSH = 2;

struct termios {
  tcflag_t        c_iflag;
  tcflag_t        c_oflag;
  tcflag_t        c_cflag;
  tcflag_t        c_lflag;
  cc_t            c_cc[20];
  speed_t         c_ispeed;
  speed_t         c_ospeed;
};


int
tcgetattr(int fildes, struct termios *termios_p);
int
tcsetattr(int fildes, int optional_actions, const struct termios *termios_p);
void
cfmakeraw(struct termios *termios_p);
