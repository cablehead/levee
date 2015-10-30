
### Pipe

Pipe is most common Levee synchronization primitive. It can have exactly 1x
sender and 1x recver. Sends will always lose context but will resume on the
next poller tick. If a sender is waiting recvs return immediately, otherwise
they block until the next send.

### Value

Sends on a Value never block, but just update the current state of the Value.
If a Value is nil, recvs will block until the next send. Subsequent recvs will
return immediately with the set value.

### Gate

A Gate ensures a senders thread cannot progress until the recv-ing thread is
ready for it too. Sends always lose context, but won't be scheduled to continue
until the recv-ing end makes a blocking recv call.


### Queue

### Stalk

### Selector



### Pair


## Combinations

	pipe -> value
	value -> pipe

	pipe -> gate
	gate -> pipe

	value -> gate
	gate -> value

	pipe -> pipe
	value -> value
	gate -> gate
