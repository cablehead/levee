#include "chan.h"

#include <stdlib.h>
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

#define CREATE_NODE(id, typ, key, val) __extension__ ({               \
	LeveeChanNode *node = malloc (sizeof *node);                      \
	if (node != NULL) {                                               \
		node->recv_id = id;                                           \
		node->type = typ;                                             \
		node->as.key = val;                                           \
	}                                                                 \
	node;                                                             \
})

#define SEND_MSG(self, typ, key, val) do {                            \
	VERIFY_EOF (self);                                                \
	LeveeChanNode *node = CREATE_NODE (self->recv_id, typ, key, val); \
	return node == NULL ? -1 : send_node (self, node);                \
} while (0)

#if defined(LEVEE_EPOLL)

static inline void
notify (LeveeChan *self)
{
	int64_t id = self->chan_id;
	write (self->chan_id, &id, sizeof id);
}

#elif defined(LEVEE_KQUEUE)

static int channel_id = 0;

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
	self->ref = 1;
	self->recv_id = 0;
	self->loopfd = loopfd;
	self->send_head = NULL;

#ifdef LEVEE_EPOLL
	self->chan_id = eventfd (0, EFD_NONBLOCK);
	if (self->chan_id < 0) {
		free (self);
		return -1;
	}

	struct epoll_event ev;
	ev.events = EPOLLIN;
	ev.data.fd = self->chan_id;
	if (epoll_ctl (loopfd, EPOLL_CTL_ADD, self->chan_id, &ev) < 0) {
		close (self->chan_id);
		free (self);
		return -1;
	}
#else
	self->chan_id = __sync_fetch_and_add (&channel_id, 1);
	struct kevent kev = {
		.ident = (uintptr_t)self->chan_id,
		.filter = EVFILT_USER,
		.flags = EV_ADD | EV_CLEAR,
	};
	if (kevent (loopfd, &kev, 1, NULL, 0, NULL) < 0) {
		free (self);
		return -1;
	}
#endif

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

	LeveeChanSender *send = ch->send_head;
	while (send != NULL) {
		LeveeChanSender *next = send->next;
		levee_chan_sender_unref (send);
		send = next;
	}

	free (ch);
}

int
levee_chan_event_id (LeveeChan **self)
{
	assert (self != NULL);

	int id = -1;
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

	snd->next = NULL;
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

	self->ref++;
	return self;
}

void
levee_chan_sender_unref (LeveeChanSender *self)
{
	if (self != NULL) {
		if (self->ref > 1) {
			self->ref--;
			return;
		}
		levee_chan_sender_close (self);
		self->chan = NULL;
		self->ref = 0;
		free (self);
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
levee_chan_send_nil (LeveeChanSender *self)
{
	assert (self != NULL);

	VERIFY_EOF (self);

	LeveeChanNode *node = malloc (sizeof *node);
	if (node == NULL) {
		return -1;
	}
	node->recv_id = self->recv_id;
	node->type = LEVEE_CHAN_NIL;
	return send_node (self, node);
}

int
levee_chan_send_ptr (LeveeChanSender *self, const void *val, size_t len)
{
	assert (self != NULL);

	SEND_MSG (self, LEVEE_CHAN_PTR, ptr, ((LeveeChanPtr){ val, len }));
}

int
levee_chan_send_dbl (LeveeChanSender *self, double val)
{
	assert (self != NULL);

	SEND_MSG (self, LEVEE_CHAN_DBL, dbl, val);
}

int
levee_chan_send_i64 (LeveeChanSender *self, int64_t val)
{
	assert (self != NULL);

	SEND_MSG (self, LEVEE_CHAN_I64, i64, val);
}

int
levee_chan_send_u64 (LeveeChanSender *self, uint64_t val)
{
	assert (self != NULL);

	SEND_MSG (self, LEVEE_CHAN_U64, u64, val);
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

	node = CREATE_NODE (self->recv_id, LEVEE_CHAN_SND, sender, sender);
	if (node == NULL) {
		id = -1;
		err = errno;
		goto out;
	}

	if (send_node (sender, node) < 0) {
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
		LeveeNode *tail = levee_list_drain (&chan->msg, false);

		// reverse the list and register any connect messages
		if (tail != NULL) {
			LeveeNode *root = tail, *next = NULL;
			tail = NULL;
			do {
				LeveeChanNode *n = container_of (root, LeveeChanNode, base);
				if (n->type == LEVEE_CHAN_SND) {
					n->as.sender->next = chan->send_head;
					chan->send_head = n->as.sender;
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

