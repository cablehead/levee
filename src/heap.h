#ifndef LEVEE_HEAP_H
#define LEVEE_HEAP_H

#include <stdint.h>

typedef struct LeveeHeap LeveeHeap;
typedef struct LeveeHeapEntry LeveeHeapEntry;
typedef struct LeveeHeapItem LeveeHeapItem;

struct LeveeHeap {
	LeveeHeapEntry **entries;
	uint32_t rows, capacity, next, value;
};

struct LeveeHeapEntry {
	int64_t priority; /* sort priority (lowest to highest) */
	LeveeHeapItem* item;
};

struct LeveeHeapItem {
	LeveeHeap *heap;
	uint32_t key;    /* reverse map to our entry in the heap */
	uint32_t value;  /* user value */
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
levee_heap_add (LeveeHeap *self, int64_t pri);

extern uint32_t
levee_heap_update (const LeveeHeap *self, uint32_t key, int64_t pri);

extern const LeveeHeapEntry *
levee_heap_get (const LeveeHeap *self, uint32_t key);

extern void
levee_heap_remove (LeveeHeap *self, uint32_t key);

extern void
levee_heap_clear (LeveeHeap *self);

#endif

