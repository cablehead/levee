static const unsigned LEVEE_BUFFER_MIN_SIZE = 8192;
static const unsigned LEVEE_BUFFER_MAX_BLOCK = 131072;

typedef struct {
	uint8_t *buf;
	uint32_t off, len, cap, sav;
} LeveeBuffer;
