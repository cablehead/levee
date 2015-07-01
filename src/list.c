#include "list.h"

#include <stddef.h>
#include <assert.h>

void
levee_list_init (LeveeList *self)
{
	assert (self != NULL);

	LeveeNode *tail;

	do {
		tail = self->tail;
	} while (!__sync_bool_compare_and_swap (&self->tail, tail, NULL));
}

void
levee_list_push (LeveeList *self, LeveeNode *node)
{
	assert (self != NULL);
	assert (node != NULL);

	LeveeNode *next;

	do {
		next = self->tail;
		node->next = next;
	} while (!__sync_bool_compare_and_swap (&self->tail, next, node));
}

LeveeNode *
levee_list_pop (LeveeList *self)
{
	assert (self != NULL);

	LeveeNode *node, *next;

	do {
		node = self->tail;
		if (node == NULL) {
			return NULL;
		}
		next = node->next;
	} while (!__sync_bool_compare_and_swap (&self->tail, node, next));
	node->next = NULL;
	return node;
}

LeveeNode *
levee_list_drain (LeveeList *self, bool reverse)
{
	assert (self != NULL);

	LeveeNode *tail;

	do {
		tail = self->tail;
	} while (!__sync_bool_compare_and_swap (&self->tail, tail, NULL));

	if (reverse && tail != NULL) {
		LeveeNode *root = tail, *next = NULL;
		tail = NULL;
		do {
			next = root->next;
			root->next = tail;
			tail = root;
			root = next;
		} while (root != NULL);
	}

	return tail;
}

