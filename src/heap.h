#ifndef LEVEE_HEAP_H
#define LEVEE_HEAP_H

#include <stdint.h>

typedef struct LeveeHeap LeveeHeap;
typedef struct LeveeHeapEntry LeveeHeapEntry;
typedef struct LeveeHeapItem LeveeHeapItem;

struct LeveeHeap {
	LeveeHeapEntry **entries;
	uint32_t rows, capacity, next;
};

struct LeveeHeapEntry {
	int64_t priority; /* sort priority (lowest to highest) */
	LeveeHeapItem* item;
};

struct LeveeHeapItem {
	uintptr_t value;  /* user value */
	uint32_t key;
};


#define LEVEE_HEAP_NO_KEY 0
#define LEVEE_HEAP_ROOT_KEY 1

extern LeveeHeap *
levee_heap_create (void);

extern void
levee_heap_destroy (LeveeHeap *self);

extern uint32_t
levee_heap_count (const LeveeHeap *self);

extern LeveeHeapItem *
levee_heap_add (LeveeHeap *self, int64_t pri, uintptr_t val);

extern uint32_t
levee_heap_update (const LeveeHeap *self, uint32_t key, int64_t pri);

extern const LeveeHeapEntry *
levee_heap_get (const LeveeHeap *self, uint32_t key);

extern uintptr_t
levee_heap_remove (LeveeHeap *self, uint32_t key, uintptr_t def);

extern void
levee_heap_clear (LeveeHeap *self);

#endif

