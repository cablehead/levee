#include "chan.h"

#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <stdio.h>
#include <errno.h>

#include <siphon/crc.h>

#define VERIFY_EOF(self) do {                                         \
	if (self->eof) {                                                  \
		errno = ENOTCONN;                                             \
		return -1;                                                    \
	}                                                                 \
} while (0)

#define CREATE_NODE(id, typ, err, key, val) __extension__ ({          \
	LeveeChanNode *node = malloc (sizeof *node);                      \
	if (node != NULL) {                                               \
		node->recv_id = id;                                           \
		node->type = typ;                                             \
		node->error = err;                                            \
		node->as.key = val;                                           \
	}                                                                 \
	node;                                                             \
})

#define SEND_MSG(self, typ, err, key, val) do {                            \
	VERIFY_EOF (self);                                                     \
	LeveeChanNode *node = CREATE_NODE (self->recv_id, typ, err, key, val); \
	return node == NULL ? -1 : send_node (self, node);                     \
} while (0)

#if defined(LEVEE_EPOLL)

static inline int
init (LeveeChan *self)
{
	int id = eventfd (0, EFD_NONBLOCK);
	if (id < 0) {
		return -1;
	}

	self->chan_id = (uint64_t) id;

	struct epoll_event ev = {
		.events = EPOLLIN | EPOLLET | EPOLLERR | EPOLLHUP,
		.data = { .u64 = LEVEE_POLL_CHANNEL }
	};
	if (epoll_ctl (self->loopfd, EPOLL_CTL_ADD, self->chan_id, &ev) < 0) {
		close (self->chan_id);
		return -1;
	}

	return 0;
}

static inline void
final (LeveeChan *self)
{
	close (self->chan_id);
}

static inline void
notify (LeveeChan *self)
{
	int64_t id = self->chan_id;
	ssize_t n = write (self->chan_id, &id, sizeof id);
	if (n < 0) {
		fprintf (stderr, "failed to write to eventfd: %s\n", strerror (errno));
	}
}

#elif defined(LEVEE_KQUEUE)

static int channel_id = 0;

static inline int
init (LeveeChan *self)
{
	uint64_t id = __sync_fetch_and_add (&channel_id, 1);
	self->chan_id = id;

	struct kevent kev = {
		.ident = (uintptr_t)self->chan_id,
		.filter = EVFILT_USER,
		.flags = EV_ADD | EV_CLEAR,
	};
	return kevent (self->loopfd, &kev, 1, NULL, 0, NULL);
}

static inline void
final (LeveeChan *self)
{
	struct kevent kev = {
		.ident = (uintptr_t)self->chan_id,
		.filter = EVFILT_USER,
		.flags = EV_DELETE,
	};
	kevent (self->loopfd, &kev, 1, NULL, 0, NULL);
}

static inline void
notify (LeveeChan *self)
{
	struct kevent kev = {
		.ident = (uintptr_t)self->chan_id,
		.filter = EVFILT_USER,
		.fflags = NOTE_TRIGGER,
	};
	kevent (self->loopfd, &kev, 1, NULL, 0, NULL);
}

#endif

static void
destroy_node (LeveeChanNode *node)
{
	if (node->type == LEVEE_CHAN_PTR) {
		free ((void *)node->as.ptr.val);
		node->as.ptr.val = NULL;
	}
	else if (node->type == LEVEE_CHAN_SND) {
		levee_chan_sender_unref (node->as.sender);
	}
	free (node);
}

static int
send_node (LeveeChanSender *self, LeveeChanNode *node)
{
	if (!self->eof) {
		LeveeChan *ch = levee_chan_ref (self->chan);
		if (ch != NULL) {
			levee_list_push (&ch->msg, &node->base);
			notify (ch);
			levee_chan_unref (self->chan);
			return 0;
		}
	}

	destroy_node (node);
	errno = ENOTCONN;
	return -1;
}

int
levee_chan_create (LeveeChan **chan, int loopfd)
{
	LeveeChan *self = malloc (sizeof *self);
	if (self == NULL) {
		return -1;
	}

	levee_list_init (&self->msg);
	levee_list_init (&self->senders);
	self->ref = 1;
	self->recv_id = 0;
	self->loopfd = loopfd;

	if (init (self) < 0) {
		free (self);
		return -1;
	}

	*chan = self;
	return 0;
}

LeveeChan *
levee_chan_ref (LeveeChan **self)
{
	if (self == NULL) {
		errno = ECONNREFUSED;
		return NULL;
	}

	LeveeChan *ch;
	uint64_t ref;

again:
	__sync_synchronize ();
	ch = *self;
	if (ch == NULL) {
		errno = ECONNREFUSED;
		return NULL;
	}
	ref = ch->ref;
	if (ref == 0) {
		errno = ECONNREFUSED;
		return NULL;
	}
	if (!__sync_bool_compare_and_swap (&ch->ref, ref, ref+1)) {
		goto again;
	}
	return ch;
}

void
levee_chan_unref (LeveeChan **self)
{
	if (self == NULL) {
		return;
	}

	LeveeChan *ch;
	uint64_t ref;

again:
	__sync_synchronize ();
	ch = *self;
	if (ch == NULL) {
		return;
	}
	ref = ch->ref;
	if (ref == 0) {
		return;
	}
	if (!__sync_bool_compare_and_swap (&ch->ref, ref, ref-1)) {
		goto again;
	}
	if (ref > 1) {
		return;
	}
	if (!__sync_bool_compare_and_swap (self, ch, NULL)) {
		// this should never happen
		fprintf (stderr, "failed deallocation CAS for channel (%s:%d)\n", __FILE__, __LINE__-2);
	}

	LeveeNode *node = levee_list_drain (&ch->msg, false);
	while (node != NULL) {
		LeveeNode *next = node->next;
		destroy_node (container_of (node, LeveeChanNode, base));
		node = next;
	}

	final (ch);
	free (ch);
}

void
levee_chan_close (LeveeChan **self)
{
	assert (self != NULL);

	LeveeChan *ch = levee_chan_ref (self);
	if (ch == NULL) {
		return;
	}

	int id = ch->chan_id;
	if (id == -1) {
		goto out;
	}

	if (!__sync_bool_compare_and_swap (&ch->chan_id, id, -1)) {
		goto out;
	}

	close (id);

	LeveeNode *node = levee_list_drain (&ch->senders, false);
	while (node != NULL) {
		LeveeNode *next = node->next;
		levee_chan_sender_unref (container_of (node, LeveeChanSender, node));
		node = next;
	}

out:
	levee_chan_unref (self);
}

uint64_t
levee_chan_event_id (LeveeChan **self)
{
	assert (self != NULL);

	uint64_t id = -1;
	LeveeChan *ch = levee_chan_ref (self);
	if (ch != NULL) {
		id = ch->chan_id;
		levee_chan_unref (self);
	}
	return id;
}

int64_t
levee_chan_next_recv_id (LeveeChan **self)
{
	assert (self != NULL);

	int64_t id = -1;
	LeveeChan *ch = levee_chan_ref (self);
	if (ch != NULL) {
		__sync_synchronize ();
		id = __sync_fetch_and_add (&ch->recv_id, 1);
		levee_chan_unref (self);
	}
	return id;
}

LeveeChanSender *
levee_chan_sender_create (LeveeChan **self, int64_t recv_id)
{
	assert (self != NULL);

	if (levee_chan_ref (self) == NULL) {
		return NULL;
	}

	LeveeChanSender *snd = malloc (sizeof *snd);
	if (snd == NULL) {
		goto out;
	}

	snd->node.next = NULL;
	snd->chan = self;
	snd->ref = 1;
	snd->recv_id = recv_id;
	snd->eof = false;

out:
	levee_chan_unref (self);
	return snd;
}

LeveeChanSender *
levee_chan_sender_ref (LeveeChanSender *self)
{
	if (self == NULL || self->ref == 0) {
		return NULL;
	}

	__sync_add_and_fetch (&self->ref, 1);
	return self;
}

void
levee_chan_sender_unref (LeveeChanSender *self)
{
	if (self != NULL) {
		if (__sync_sub_and_fetch (&self->ref, 1) == 0) {
			levee_chan_sender_close (self);
			self->chan = NULL;
			self->ref = 0;
			free (self);
		}
	}
}

int
levee_chan_sender_close (LeveeChanSender *self)
{
	assert (self != NULL);

	if (!self->eof) {
		LeveeChanNode *node = malloc (sizeof *node);
		if (node == NULL) {
			return -1;
		}
		node->recv_id = self->recv_id;
		node->type = LEVEE_CHAN_EOF;
		if (send_node (self, node) < 0) {
			return -1;
		}
		self->eof = true;
	}
	return 0;
}

int
levee_chan_send_nil (LeveeChanSender *self, int err)
{
	assert (self != NULL);

	VERIFY_EOF (self);

	LeveeChanNode *node = malloc (sizeof *node);
	if (node == NULL) {
		return -1;
	}
	node->recv_id = self->recv_id;
	node->type = LEVEE_CHAN_NIL;
	node->error = err;
	return send_node (self, node);
}

int
levee_chan_send_ptr (LeveeChanSender *self, int err, const void *val, uint32_t len, LeveeChanFormat fmt)
{
	assert (self != NULL);

	SEND_MSG (self, LEVEE_CHAN_PTR, err, ptr, ((LeveeChanPtr){ val, len, fmt }));
}

// TODO: len is only needed as we don't have LeveeBuffer defined in C
int
levee_chan_send_buf (LeveeChanSender *self, int err, LeveeBuffer *buf)
{
	assert (self != NULL);

	SEND_MSG (self, LEVEE_CHAN_BUF, err, ptr, ((LeveeChanPtr){ buf, sizeof(buf), LEVEE_CHAN_RAW }));
}

int
levee_chan_send_obj (LeveeChanSender *self, int err, void *obj, void (*free)(void *obj))
{
	assert (self != NULL);

	SEND_MSG (self, LEVEE_CHAN_OBJ, err, obj, ((LeveeChanObj){ obj, free }));
}

int
levee_chan_send_dbl (LeveeChanSender *self, int err, double val)
{
	assert (self != NULL);

	SEND_MSG (self, LEVEE_CHAN_DBL, err, dbl, val);
}

int
levee_chan_send_i64 (LeveeChanSender *self, int err, int64_t val)
{
	assert (self != NULL);

	SEND_MSG (self, LEVEE_CHAN_I64, err, i64, val);
}

int
levee_chan_send_u64 (LeveeChanSender *self, int err, uint64_t val)
{
	assert (self != NULL);

	SEND_MSG (self, LEVEE_CHAN_U64, err, u64, val);
}

int
levee_chan_send_bool (LeveeChanSender *self, int err, bool val)
{
	assert (self != NULL);

	SEND_MSG (self, LEVEE_CHAN_BOOL, err, b, val);
}

int64_t
levee_chan_connect (LeveeChanSender *self, LeveeChan **chan)
{
	assert (self != NULL);

	VERIFY_EOF (self);

	LeveeChanNode *node = NULL;
	LeveeChanSender *sender = NULL;
	int64_t id = -1;
	int err = 0;

	id = levee_chan_next_recv_id (chan);
	if (id < 0) {
		err = errno;
		goto out;
	}

	sender = levee_chan_sender_create (chan, id);
	if (sender == NULL) {
		id = -1;
		err = errno;
		goto out;
	}

	node = CREATE_NODE (self->recv_id, LEVEE_CHAN_SND, 0, sender, sender);
	if (node == NULL) {
		id = -1;
		err = errno;
		goto out;
	}

	if (send_node (self, node) < 0) {
		id = -1;
		err = errno;
	}
	// send will clean up values on error
	sender = NULL;
	node = NULL;

out:
	free (node);
	free (sender);
	errno = err;
	return id;
}

LeveeChanNode *
levee_chan_recv (LeveeChan **self)
{
	assert (self != NULL);

	LeveeChanNode *node = NULL;
	LeveeChan *chan = levee_chan_ref (self);
	if (chan != NULL) {
#if defined(LEVEE_EPOLL)
		int64_t id;
		ssize_t n = read (chan->chan_id, &id, sizeof id);
		if (n < 0) {
			fprintf (stderr, "failed to read to eventfd: %s\n", strerror (errno));
		}
#endif
		LeveeNode *tail = levee_list_drain (&chan->msg, false);

		// reverse the list and register any connect messages
		if (tail != NULL) {
			LeveeNode *root = tail, *next = NULL;
			tail = NULL;
			do {
				LeveeChanNode *n = container_of (root, LeveeChanNode, base);
				if (n->type == LEVEE_CHAN_SND) {
					levee_list_push (&chan->senders, &n->as.sender->node);
				}
				next = root->next;
				root->next = tail;
				tail = root;
				root = next;
			} while (root != NULL);
		}

		node = container_of (tail, LeveeChanNode, base);
		levee_chan_unref (self);
	}
	return node;
}

LeveeChanNode *
levee_chan_recv_next (LeveeChanNode *node)
{
	if (node == NULL) {
		return NULL;
	}

	LeveeChanNode *next = container_of (node->base.next, LeveeChanNode, base);
	destroy_node (node);
	return next;
}

