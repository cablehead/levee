typedef volatile struct LeveeList LeveeList;
typedef struct LeveeNode LeveeNode;

struct LeveeList {
	LeveeNode *tail;
} __attribute__ ((aligned (16)));

struct LeveeNode {
	LeveeNode *next;
};

extern void
levee_list_init (LeveeList *self);

extern void
levee_list_push (LeveeList *self, LeveeNode *node);

extern LeveeNode *
levee_list_pop (LeveeList *self);

extern LeveeNode *
levee_list_drain (LeveeList *self, bool reverse);

