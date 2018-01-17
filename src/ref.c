#include "ref.h"

#include <stdlib.h>
#include <pthread.h>
#include <time.h>
#include <stdio.h>

struct LeveeRef_s {
	int64_t ref;
	union {
		void *ptr;
		LeveeRef *next;
	} as;
} __attribute__ ((aligned (16)));

static LeveeRef sentinel = { -INT64_MAX, { NULL } };

static struct {
	LeveeRef *head, *tail;
} stale = { &sentinel, &sentinel };

static pthread_mutex_t stale_lock = PTHREAD_MUTEX_INITIALIZER;

static void
discard (LeveeRef *r)
{
	pthread_mutex_lock (&stale_lock);
	stale.tail->as.next = r;
	stale.tail = r;
	pthread_mutex_unlock (&stale_lock);
}

static LeveeRef *
restore (void)
{
	LeveeRef *ref = NULL;
	int64_t n = -time (NULL);
	if (n <= stale.head->ref && pthread_mutex_trylock (&stale_lock) == 0) {
		if (n <= stale.head->ref) {
			ref = stale.head;
			stale.head = ref->as.next;
		}
		pthread_mutex_unlock (&stale_lock);
	}
	return ref;
}

inline static bool
cas (LeveeRef *r, LeveeRef cmp, LeveeRef new)
{
	bool out;
	__asm__ __volatile__ (
		 "lock cmpxchg16b %1\n\t"
		 "setz %0"
		 : "=q" ( out )
		 , "+m" ( *r )
		 , "+d" ( cmp.as.ptr )
		 , "+a" ( cmp.ref )
		 : "c" ( new.as.ptr )
		 , "b" ( new.ref )
		 : "cc", "memory"
	);
	return out;
}

LeveeRef *
levee_ref_make (void *ptr)
{
	LeveeRef *r = restore ();
	if (r == NULL) {
		r = malloc (sizeof *r);
		if (r == NULL) {
			return NULL;
		}
	}
	r->ref = 1;
	r->as.ptr = ptr;
	return r;
}

void *
levee_ref (LeveeRef *r)
{
	LeveeRef cmp, new;

	do {
		cmp = *r;
		if (cmp.ref < 1) {
			return NULL;
		}
		new.ref = cmp.ref + 1;
		new.as.ptr = cmp.as.ptr;
	} while (!cas (r, cmp, new));

	return new.as.ptr;
}

void *
levee_unref (LeveeRef *r)
{
	LeveeRef cmp, new;
	void *out;

	do {
		cmp = *r;
		if (cmp.ref <= 1) {
			out = cmp.as.ptr;
			new.ref = -30 - time (NULL);
			new.as.ptr = NULL;
		}
		else {
			out = NULL;
			new.ref = cmp.ref - 1;
			new.as.ptr = cmp.as.ptr;
		}
	} while (!cas (r, cmp, new));

	if (out != NULL) {
		discard (r);
	}

	return out;
}

