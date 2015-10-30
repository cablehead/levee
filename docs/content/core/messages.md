
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

Sends on a Value never block, but just update the current state of the Value.
If a Value is nil, recvs will block until the next send. Subsequent recvs will
return immediately with the set value.

### Gate

A Gate ensures a senders thread cannot progress until the recv-ing thread is
ready for it too. Sends always lose context, but won't be scheduled to continue
until the recv-ing end makes a blocking recv call.

### Queue

A queue is exactly one Sender and one Recver with a fifo in between. Sends
won't block until the fifo is filled. Sends will return immediately if a recver
is ready.

### Stalk

A Stalk is a delayed queue. Recv-ing on the Stalk returns true once there are
items in the queue, but it doesn't actually return a sent item. The queue can
then be processed and optionally cleared. Once cleared if there is a pending
upstream sender it will be signaled to continue.

### Selector

A Selector coalesces many Senders into one Recver. Senders always lose context
and will continue on the next poller tick after they have been recv'd.



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
