typedef struct {
	const void *type;
	void *entries;
	double loadf;
	SpBloom *bloom;
	size_t capacity, max, count, mask, mod;
} SpMap;
