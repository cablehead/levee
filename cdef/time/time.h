typedef long time_t;

struct timeval {
	time_t tv_sec;
	time_t tv_usec;
};

struct timespec {
	time_t tv_sec;
	long tv_nsec;
};

struct tm {
	int	tm_sec;		/* seconds after the minute [0-60] */
	int	tm_min;		/* minutes after the hour [0-59] */
	int	tm_hour;	/* hours since midnight [0-23] */
	int	tm_mday;	/* day of the month [1-31] */
	int	tm_mon;		/* months since January [0-11] */
	int	tm_year;	/* years since 1900 */
	int	tm_wday;	/* days since Sunday [0-6] */
	int	tm_yday;	/* days since January 1 [0-365] */
	int	tm_isdst;	/* Daylight Savings Time flag */
	long tm_gmtoff;	/* offset from CUT in seconds */
	char *tm_zone;	/* timezone abbreviation */
};

int gettimeofday (struct timeval* t, void* tzp);
time_t time(time_t *tloc);
struct tm * gmtime_r(const time_t *clock, struct tm *result);
struct tm * localtime_r(const time_t *clock, struct tm *result);
char *strptime(const char *s, const char *format, struct tm *tm);
size_t strftime(char *restrict s, size_t maxsize, const char *restrict format, const struct tm *restrict timeptr);
time_t timegm(struct tm *timeptr);
time_t mktime(struct tm *timeptr);


struct rusage {
	struct timeval ru_utime; /* user time used */
	struct timeval ru_stime; /* system time used */
	long ru_maxrss;          /* max resident set size */
	long ru_ixrss;           /* integral shared text memory size */
	long ru_idrss;           /* integral unshared data size */
	long ru_isrss;           /* integral unshared stack size */
	long ru_minflt;          /* page reclaims */
	long ru_majflt;          /* page faults */
	long ru_nswap;           /* swaps */
	long ru_inblock;         /* block input operations */
	long ru_oublock;         /* block output operations */
	long ru_msgsnd;          /* messages sent */
	long ru_msgrcv;          /* messages received */
	long ru_nsignals;        /* signals received */
	long ru_nvcsw;           /* voluntary context switches */
	long ru_nivcsw;          /* involuntary context switches */
};

static const int RUSAGE_SELF     =   0;
static const int RUSAGE_CHILDREN =  -1;

int
getrusage(int who, struct rusage *r_usage);
