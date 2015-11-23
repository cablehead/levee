typedef struct SpRing SpRing;

typedef struct {
	SpRing *ring;
	size_t keylen;
	int avail;
	uint8_t _key[1];
} SpRingNode;

typedef struct {
	uint64_t hash;
	SpRingNode *node;
} SpRingReplica;

struct SpRing {
	SpMap nodes;
	SpRingReplica *replicas;
	SpHash hash;
};

int
sp_ring_init (SpRing *self, SpHash fn);

void
sp_ring_final (SpRing *self);

int
sp_ring_put (SpRing *self,
		const void *restrict key, size_t len,
		unsigned replicas, int avail);

const SpRingNode *
sp_ring_get (const SpRing *self, const void *restrict key, size_t len);

bool
sp_ring_del (SpRing *self, const void *restrict key, size_t len);

const SpRingReplica *
sp_ring_find (const SpRing *self, const void *restrict val, size_t len);

const SpRingReplica *
sp_ring_next (const SpRing *self, const SpRingReplica *rep);

const SpRingNode *
sp_ring_reserve (const SpRing *self, const SpRingReplica *rep);

void
sp_ring_restore (const SpRing *self, const SpRingNode *node);
