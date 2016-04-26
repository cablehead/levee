#include "ref.h"
#include <stdlib.h>

struct LeveeRef {
	int64_t ref;
	void *ptr;
} __attribute__ ((aligned (16)));

inline static bool
cas (LeveeRef *r, LeveeRef cmp, LeveeRef new)
{
	bool out;
	__asm__ __volatile__ (
		 "lock cmpxchg16b %1\n\t"
		 "setz %0"
		 : "=q" ( out )
		 , "+m" ( *r )
		 , "+d" ( cmp.ptr )
		 , "+a" ( cmp.ref )
		 : "c" ( new.ptr )
		 , "b" ( new.ref )
		 : "cc", "memory"
	);
	return out;
}

LeveeRef *
levee_ref_make (void *ptr)
{
	LeveeRef *r = malloc (sizeof *r);
	if (r != NULL) {
		r->ref = 1;
		r->ptr = ptr;
	}
	return r;
}

void *
levee_ref (LeveeRef *r)
{
	LeveeRef cmp, new;

	do {
		cmp = *r;
		new.ref = cmp.ref + 1;
		new.ptr = cmp.ptr;
	} while (!cas (r, cmp, new));

	return new.ptr;
}

void *
levee_unref (LeveeRef *r)
{
	LeveeRef cmp, new;
	void *out;

	do {
		cmp = *r;
		new.ref = cmp.ref - 1;
		if (new.ref < 1) {
			out = cmp.ptr;
			new.ptr = NULL;
		}
		else {
			out = NULL;
			new.ptr = cmp.ptr;
		}
	} while (!cas (r, cmp, new));

	return out;
}

