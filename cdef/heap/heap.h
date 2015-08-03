typedef struct LeveeHeap LeveeHeap;
typedef struct LeveeHeapEntry LeveeHeapEntry;
typedef struct LeveeHeapItem LeveeHeapItem;

struct LeveeHeapEntry {
	int64_t priority; /* sort priority (lowest to highest) */
	LeveeHeapItem* item;
};

struct LeveeHeapItem {
	uintptr_t value;  /* user value */
	uint32_t key;
};

static const int LEVEE_HEAP_NO_KEY = 0;
static const int LEVEE_HEAP_ROOT_KEY = 1;

LeveeHeap * levee_heap_create (void);
void levee_heap_destroy (LeveeHeap *self);
uint32_t levee_heap_count (const LeveeHeap *self);
LeveeHeapItem * levee_heap_add (LeveeHeap *self, int64_t pri, uintptr_t val);
const LeveeHeapEntry *levee_heap_get (const LeveeHeap *self, uint32_t key);
uintptr_t levee_heap_remove (LeveeHeap *self, uint32_t key, uintptr_t def);
void levee_heap_clear (LeveeHeap *self);
