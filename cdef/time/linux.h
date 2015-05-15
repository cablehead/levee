typedef enum {
	CLOCK_REALTIME           = 0,
	CLOCK_MONOTONIC          = 1,
	CLOCK_PROCESS_CPUTIME_ID = 2,
	CLOCK_THREAD_CPUTIME_ID  = 3,
	CLOCK_MONOTONIC_RAW      = 4,
	CLOCK_REALTIME_COARSE    = 5,
	CLOCK_MONOTONIC_COARSE   = 6,
	CLOCK_BOOTTIME           = 7,
} clockid_t;

int clock_gettime(clockid_t clk_id, struct timespec *tp);
