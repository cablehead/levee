typedef struct {
	const void *type;
	void *entries;
	size_t capacity, max, count, mask;
	double loadf;
	SpBloom *bloom;
} SpMap;
