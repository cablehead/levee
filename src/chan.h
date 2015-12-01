#ifndef LEVEE_CHAN_H
#define LEVEE_CHAN_H

typedef struct LeveeChan LeveeChan;
typedef struct LeveeChanSender LeveeChanSender;

#include "levee.h"
#include "buffer.h"
#include "list.h"

typedef enum {
	LEVEE_CHAN_EOF,
	LEVEE_CHAN_NIL,
	LEVEE_CHAN_PTR,
	LEVEE_CHAN_OBJ,
	LEVEE_CHAN_BUF,
	LEVEE_CHAN_DBL,
	LEVEE_CHAN_I64,
	LEVEE_CHAN_U64,
	LEVEE_CHAN_BOOL,
	LEVEE_CHAN_SND
} LeveeChanType;

typedef enum {
	LEVEE_CHAN_RAW,
	LEVEE_CHAN_MSGPACK
} LeveeChanFormat;

typedef struct {
	const void *val;
	uint32_t len;
	LeveeChanFormat fmt;
} LeveeChanPtr;

typedef struct {
	void *obj;
	void (*free)(void *obj);
} LeveeChanObj;

typedef struct {
	LeveeNode base;
	int64_t recv_id;
	LeveeChanType type;
	int error;
	union {
		LeveeChanPtr ptr;
		LeveeChanObj obj;
		double dbl;
		int64_t i64;
		uint64_t u64;
		bool b;
		LeveeChanSender *sender;
	} as;
} LeveeChanNode;

struct LeveeChan {
	LeveeList msg, senders;
	int64_t ref;
	int64_t recv_id;
	int loopfd;
	uint64_t chan_id;
};

struct LeveeChanSender {
	LeveeNode node;
	LeveeChan **chan;
	int64_t ref;
	int64_t recv_id;
	bool eof;
};

extern int
levee_chan_create (LeveeChan **chan, int loopfd);

extern LeveeChan *
levee_chan_ref (LeveeChan **self);

extern void
levee_chan_unref (LeveeChan **self);

extern void
levee_chan_close (LeveeChan **self);

extern uint64_t
levee_chan_event_id (LeveeChan **self);

extern int64_t
levee_chan_next_recv_id (LeveeChan **self);

extern LeveeChanSender *
levee_chan_sender_create (LeveeChan **self, int64_t recv_id);

extern LeveeChanSender *
levee_chan_sender_ref (LeveeChanSender *self);

extern void
levee_chan_sender_unref (LeveeChanSender *self);

extern int
levee_chan_sender_close (LeveeChanSender *self);

extern int
levee_chan_send_nil (LeveeChanSender *self, int err);

extern int
levee_chan_send_ptr (LeveeChanSender *self, int err,
		const void *val, uint32_t len,
		LeveeChanFormat fmt);

extern int
levee_chan_send_buf (LeveeChanSender *self, int err,
		LeveeBuffer *buf);

extern int
levee_chan_send_obj (LeveeChanSender *self, int err,
		void *obj, void (*free)(void *obj));

extern int
levee_chan_send_dbl (LeveeChanSender *self, int err, double val);

extern int
levee_chan_send_i64 (LeveeChanSender *self, int err, int64_t val);

extern int
levee_chan_send_u64 (LeveeChanSender *self, int err, uint64_t val);

extern int
levee_chan_send_bool (LeveeChanSender *self, int err, bool val);

extern int64_t
levee_chan_connect (LeveeChanSender *self, LeveeChan **chan);

extern LeveeChanNode *
levee_chan_recv (LeveeChan **self);

extern LeveeChanNode *
levee_chan_recv_next (LeveeChanNode *node);

#endif

