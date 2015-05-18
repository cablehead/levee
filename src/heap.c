#include "heap.h"

#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>

#define ROW_SHIFT   15
#define ROW_WIDTH   (1 << ROW_SHIFT)
#define ROW(b, n)   ((b)->entries[(n) >> ROW_SHIFT])
#define ENTRY(b, n)  ROW(b, n)[(n) & (ROW_WIDTH - 1)]

static uint32_t parent (uint32_t key);
static void child (uint32_t key, uint32_t *a, uint32_t *b);
static int add_row (LeveeHeap *);
static void swap (const LeveeHeap *, uint32_t aidx, uint32_t bidx);
static uint32_t move_up (const LeveeHeap *, uint32_t key);
static uint32_t move_down (const LeveeHeap *, uint32_t key);

static uint32_t page_size, page_mask, page_shift;

static void __attribute__((constructor))
init (void)
{
	uint32_t pow;

	page_size = (uint32_t)getpagesize () / sizeof (LeveeHeapEntry);
	page_mask = page_size - 1;
	assert (!(page_size & page_mask));
	for (pow = 1; (1U << pow) != page_size; pow++)
		;
	page_shift = pow;
	assert (page_size <= sizeof (LeveeHeapEntry) * ROW_WIDTH);
}

LeveeHeap *
levee_heap_create (void)
{
	LeveeHeap *self = calloc (1, sizeof (struct LeveeHeap));
	if (self == NULL) {
		return NULL;
	}

	self->next = LEVEE_HEAP_ROOT_KEY;
	self->rows = 16;
	self->entries = calloc (self->rows, sizeof *self->entries);
	if (self->entries == NULL) {
		free (self);
		return NULL;
	}
	if (add_row (self) < 0) {
		free (self->entries);
		free (self);
		return NULL;
	}
	return self;
}

void
levee_heap_destroy (LeveeHeap *self)
{
	if (self == NULL) {
		return;
	}

	levee_heap_clear (self);
	free (self->entries[0]);
	free (self->entries);
	free (self);
}

uint32_t
levee_heap_count (const LeveeHeap *self)
{
	assert (self != NULL);

	return self->next - 1;
}

uint32_t
levee_heap_add (LeveeHeap *self, int64_t pri, uintptr_t val)
{
	assert (self != NULL);
	assert (self->capacity >= self->next);

	uint32_t key;

	if (self->capacity == self->next && add_row (self) < 0) {
		return LEVEE_HEAP_NO_KEY;
	}
	key = self->next++;
	ENTRY (self, key).priority = pri;
	ENTRY (self, key).value = val;
	return move_up (self, key);
}

uint32_t
levee_heap_update (const LeveeHeap *self, uint32_t key, int64_t pri)
{
	assert (self != NULL);
	assert (self->next > LEVEE_HEAP_ROOT_KEY);

	if (key == 0 || key >= self->next) {
		return LEVEE_HEAP_NO_KEY;
	}

	ENTRY (self, key).priority = pri;

	key = move_up (self, key);
	return move_down (self, key);
}

const LeveeHeapEntry *
levee_heap_get (const LeveeHeap *self, uint32_t key)
{
	assert (self != NULL);

	if (key == 0 || key >= self->next) {
		return NULL;
	}
	return &ENTRY (self, key);
}

int64_t
levee_heap_priority (const LeveeHeap *self, uint32_t key, int64_t def)
{
	assert (self != NULL);

	if (key == 0 || key >= self->next) {
		return def;
	}
	return ENTRY (self, key).priority;
}

uintptr_t
levee_heap_remove (LeveeHeap *self, uint32_t key, uintptr_t def)
{
	assert (self != NULL);
	assert (self->next > LEVEE_HEAP_ROOT_KEY);

	if (key == 0 || key >= self->next) {
		return def;
	}

	def = ENTRY (self, key).value;
	if (key != --self->next) {
		ENTRY (self, key) = ENTRY (self, self->next);
		key = move_up (self, key);
		move_down (self, key);
	}

	// always keep one extra row when removing
	if ((((self->next + ROW_WIDTH - 2) / ROW_WIDTH) + 1) * ROW_WIDTH < self->capacity) {
		free (ROW (self, self->capacity - 1));
		ROW (self, self->capacity - 1) = NULL;
		self->capacity -= ROW_WIDTH;
	}
	return def;
}

void
levee_heap_clear (LeveeHeap *self)
{
	assert (self != NULL);

	for (uint32_t i = (self->capacity / ROW_WIDTH) - 1; i > 0; i--) {
		free (self->entries[i]);
	}
	self->next = LEVEE_HEAP_ROOT_KEY;
	self->capacity = ROW_WIDTH;
}

uint32_t
parent (uint32_t key)
{
	assert (key != UINT32_MAX);

	uint32_t mask, pidx;

	mask = key & page_mask;
	if (key < page_size || mask > 3) {
		pidx = (key & ~page_mask) | (mask >> 1);
	}
	else if (mask < 2) {
		pidx = (key - page_size) >> page_shift;
		pidx += pidx & ~(page_mask >> 1);
		pidx |= page_size / 2;
	}
	else {
		pidx = key - 2;
	}
	return pidx;
}

void
child (uint32_t key, uint32_t *a, uint32_t *b)
{
	uintmax_t uu;

	if (key > page_mask && (key & (page_mask - 1)) == 0) {
		*a = *b = key + 2;
	}
	else if (key & (page_size >> 1)) {
		*a = (key & ~page_mask) >> 1;
		*a |= key & (page_mask >> 1);
		*a += 1;
		uu = (uintmax_t)*a << page_shift;
		*a = (uint32_t)uu;
		if (*a == uu) {
			*b = *a + 1;
		}
		else {
			*a = UINT32_MAX;
			*b = UINT32_MAX;
		}
	}
	else {
		*a = key + (key & page_mask);
		*b = *a + 1;
	}
}

int
add_row (LeveeHeap *self)
{
	if (&ROW (self, self->capacity) >= self->entries + self->rows) {
		LeveeHeapEntry **entries = realloc (self->entries, sizeof *entries * self->rows * 2);
		if (!entries) {
			return -1;
		}
		memset (entries + self->rows, 0, self->rows * sizeof *entries);
		self->entries = entries;
		self->rows *= 2;
	}
	ROW (self, self->capacity) = malloc (sizeof **self->entries * ROW_WIDTH);
	self->capacity += ROW_WIDTH;
	return 0;
}

void
swap (const LeveeHeap *self, uint32_t aidx, uint32_t bidx)
{
	assert (self != NULL);
	assert (aidx < self->next);
	assert (bidx < self->next);

	LeveeHeapEntry tmp;

	tmp = ENTRY (self, aidx);
	ENTRY (self, aidx) = ENTRY (self, bidx);
	ENTRY (self, bidx) = tmp;
}

uint32_t
move_up (const LeveeHeap *self, uint32_t key)
{
	assert (self != NULL);
	assert (key < self->next);

	uint32_t pidx;

	while (key > LEVEE_HEAP_ROOT_KEY) {
		pidx = parent (key);
		if (ENTRY (self, key).priority >= ENTRY (self, pidx).priority) {
			break;
		}
		swap (self, key, pidx);
		key = pidx;
	}
	return key;
}

uint32_t
move_down (const LeveeHeap *self, uint32_t key)
{
	assert (self != NULL);
	assert (key < self->next);

	uint32_t cidx1, cidx2;

	while (1) {
		child (key, &cidx1, &cidx2);
		if (cidx1 >= self->next) {
			return key;
		}
		if (cidx1 != cidx2 && cidx2 < self->next) {
			if (ENTRY (self, cidx2).priority < ENTRY (self, cidx1).priority) {
				cidx1 = cidx2;
			}
		}
		if (ENTRY (self, key).priority < ENTRY (self, cidx1).priority) {
			return key;
		}
		swap (self, key, cidx1);
		key = cidx1;
	}
}

