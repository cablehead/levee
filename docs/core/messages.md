## Hub...

* pipe():
  returns `sender`, `recver`

* value():
  returns `sender`, `recver`

* gate():
  returns `sender`, `recver`

* queue(size):
  returns `sender`, `recver`

* stalk(size):
  returns `sender`, `recver`

* selector():
  returns `recver`

* dealer():
  returns `sender`, `recver`

* pool(factory, size):
  returns `pool`


### Sender


### Recver



### Pipe

Pipe is most common Levee synchronization primitive. It can have exactly 1x
sender and 1x recver. Sends will always lose context but will resume on the
next poller tick. If a sender is waiting recvs return immediately, otherwise
they block until the next send.

#### methods

* send(value):
  return `err` where `err` is potentially `levee.errors.CLOSED`.

* recv(ms):
  returns `err`, `value`. where `value` is a sent value, or `err` is
  `levee.errors.CLOSED` or `levee.errors.TIMEOUT` is the recv is blocked for
  more than `ms` milliseconds.

* close():
  return `err`


#### iteration

```lua
  local p = h:pipe()
  for i in p do
    -- yields values until an error is encountered
  end
```

### Value

Specialized Sender.

Sends on a Value never block, but just update the current state of the Value.
If a Value is nil, recvs will block until the next send. Subsequent recvs will
return immediately with the set value.

### Gate

Specialized Sender.

A Gate ensures a senders thread cannot progress until the recv-ing thread is
ready for it too. Sends always lose context, but won't be scheduled to continue
until the recv-ing end makes a blocking recv call.

### Queue

Specialized Recver.

A queue is exactly one Sender and one Recver with a fifo in between. Sends
won't block until the fifo is filled. Sends will return immediately if a recver

#### attributes:

* empty:
  `empty` is a Value which will be `true` when the queue is empty and unset
  otherwise. this gives the ability to block until the queue is empty.

### Stalk

Specialized Recver.

A Stalk is a delayed queue. Recv-ing on the Stalk returns true once there are
items in the queue, but it doesn't actually return a sent item. The queue can
then be processed and optionally cleared. Once cleared if there is a pending
upstream sender it will be signaled to continue.

### Selector

Specialized Recver.

A Selector coalesces many Senders into one Recver. Senders always lose context
and will continue on the next poller tick after they have been recv'd.

### Dealer

Specialized Recver.

A Dealer allows many recvers. recvers will be queued first in, first out.

### Pool(factory, size)

Pool is a finite set of resources that can be shared. `factory` is a callable
which returns a resource item to add to the pool. `size` is the number of
resources the pool should contain.

#### methods

* recv(ms):
  returns `err`, `item`. `item` is an item from the resource pool. if no
  resources are available this call will block until one is.

* send(item):
  returns `item` to the resource pool.  return `err`.

* run(f, ...):
  convenience to run `f(item, ...)` where `item` is an item checked out from the
  pool. `item` will be returned to the pool after `f` completes.


### Pair


## Combinations

  pipe -> value
  value -> pipe

  pipe -> gate
  gate -> pipe

  value -> gate
  gate -> value

  pipe -> selector
  gate -> selector
  value -> selector

  pipe -> queue
  gate -> queue
  value -> queue

  pipe -> stalk
  gate -> stalk
  value -> stalk



  pipe -> pipe
  value -> value
  gate -> gate
