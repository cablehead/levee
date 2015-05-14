#include <stdio.h>
#include <stdlib.h>
#include "heap.h"
#include "mu.h"

int
main (void)
{
	LeveeHeap *heap = levee_heap_create ();
	if (heap == NULL) {
		return 1;
	}
	srand (0);
	for (int i = 0; i < 1000000; i++) {
		int pri = rand ();
		uintptr_t val = ((uintptr_t)pri << 32) | (i & 0xFFFF);
		levee_heap_add (heap, pri, val);
	}
	int last = -1;
	for (int i = 0; i < 1000000; i++) {
		uintptr_t val = levee_heap_remove (heap, LEVEE_HEAP_ROOT_KEY, 0);
		int pri = val >> 32;
		mu_assert_int_ge (pri, last);
		last = pri;
	}
	levee_heap_destroy (heap);

	mu_exit ("heap");
}

