struct mach_timebase_info {
	uint32_t numer;
	uint32_t denom;
};

typedef struct mach_timebase_info * mach_timebase_info_t;
typedef struct mach_timebase_info   mach_timebase_info_data_t;

int mach_timebase_info(mach_timebase_info_t info);
uint64_t mach_absolute_time(void);
