typedef struct LeveeHeap LeveeHeap;
typedef struct LeveeHeapEntry LeveeHeapEntry;
typedef struct LeveeHeapItem LeveeHeapItem;

struct LeveeHeapEntry {
	int64_t priority; /* sort priority (lowest to highest) */
	LeveeHeapItem* item;
};

struct LeveeHeapItem {
	LeveeHeap *heap;
	uint32_t key;    /* reverse map to our entry in the heap */
};

static const int LEVEE_HEAP_NO_KEY = 0;
static const int LEVEE_HEAP_ROOT_KEY = 1;

LeveeHeap *
levee_heap_create (void);

void
levee_heap_destroy (LeveeHeap *self);

uint32_t
levee_heap_count (const LeveeHeap *self);

uint32_t
levee_heap_update (const LeveeHeap *self, uint32_t key, int64_t pri);

LeveeHeapItem *
levee_heap_add (LeveeHeap *self, int64_t pri);

const LeveeHeapEntry *
levee_heap_get (const LeveeHeap *self, uint32_t key);

void
levee_heap_remove (LeveeHeap *self, uint32_t key);

void
levee_heap_clear (LeveeHeap *self);
