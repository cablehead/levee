typedef union {
	struct { uint64_t low, high; } u128;
	uint64_t u64;
	uint32_t u32;
	uint8_t bytes[16];
} SpSeed;

const SpSeed *const restrict SP_SEED_RANDOM;
const SpSeed *const restrict SP_SEED_DEFAULT;

typedef uint64_t (*SpHash)(const void *restrict key, size_t len, const SpSeed *restrict seed);

uint32_t
sp_crc32 (uint32_t crc, const void *bytes, size_t len);

uint32_t
sp_crc32c (uint32_t crc, const void *bytes, size_t len);

uint64_t
sp_metrohash64 (const void *restrict s, size_t len, const SpSeed *restrict seed);

uint64_t
sp_siphash (const void *restrict s, size_t len, const SpSeed *restrict seed);

uint64_t
sp_siphash_case (const void *restrict s, size_t len, const SpSeed *restrict seed);

