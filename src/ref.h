#ifndef LEVEE_REF_H
#define LEVEE_REF_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

typedef volatile struct LeveeRef_s LeveeRef;

extern LeveeRef *
levee_ref_make (void *ptr);

extern void *
levee_ref (LeveeRef *r);

extern void *
levee_unref (LeveeRef *r);

#endif

