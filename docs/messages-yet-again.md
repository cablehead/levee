
# Up until now

The message passing API for Levee isn't right. It attempts to capture some, on
the surface, good ideas. The end result when you go to use it though isn't what
you want and clumsy.

These are three key ideas I really tried to embrace for it

- Strictly enforce the distinction between `1x` vs `Nx` communication. E.g.
  whether a message channel would have only one, or more then one senders, or
  recvers. Ideas behind this were:

  - The data structure for `1x` is cheaper than `Nx`, since `Nx` uses a
    `fifo`

  - It's important to enforce that you meant to have `Nx`. If you didn't,
    and you accidentally allowed a message channel to end up in two coroutines,
    unexpected things could happen, e.g. you could break serialization of a
    message stream.

  - I read too many books on data flow and found the concept cool.

- Enforce the separation between sender and recver. Ideas behind this were:

  - It's important to enforce the separation, to prevent accidentally having
    the wrong coroutine getting a handle on the wrong end, and to make code
    clearer. IE, this function must be a producer, since it's passed a sender
    and this must be a consumer, since it's passed a recver.

  - Go allows you to do this, I think largely for the above reason, so I
    thought it'd give the API *cred*.

  - It makes things clearer use wise, when you begin to `pipe` one message
    channel into another.

- Provide the concept of piping a message channel into another. Ideas behind
  this were:

  - Strictly enforcing the distinction between `1x` vs `Nx` almost demands you
    need this, as you constantly need to adapt from what how a producer was
    written for (say `1x`) and when you might to use it differently.

  - You should be able to optimize performance, so the effect after piping is
    message channel is a minimal as it could be after a pipe. E.g., a naive
    but inefficient implementation method to pipe is:

```lua
    h:spawn(function()
        for data in up.recver do
            down.sender:send(data)
        end
        down.sender:close()
    end)
```

I now think these ideas are doing more harm than good.

Another idea that's in the mix, that I really find useful is the idea of the
*nature* of the message passing channel. ATM there's only really two: `pipe`
and `value`. It's hard to exploit these though, as you end up tripping up on
one of the above restrictions. E.g. `h:value()` can only have 1x sender and 1x
recver. What if you want that nature with `Nx` on one end?

# Possible refactor

## Drop the `1x` vs `Nx` distinction?

- This would get rid of the `pipe` vs `router` vs `dealer` distinction.

- If the replacement is just `pipe`, the first sender to send on the pipe
  doesn't create the `fifo`. When a second sender goes to send, the `fifo` is
  created.

- This should address the data structure expense concern. It does add a test
  for every message sent though, to see if the current data structure is right.

- We lose the safety enforcement. I'm now inclined to put this in the
  interpreted vs statically compiled bucket though. We choose to forgo the
  safety for the convenience.

## Drop the separation of sender and recver?

- Need to think about backwards compatibility. This one is a straight up trade
  off between a more intuitive API, vs explicit.

## Drop the concept of piping?

- In practice because of the current distinctions, things are so clumsy it
  either hasn't been implemented for all types of message channels, or, even
  when it is, it's easier to explicitly do that naive piping above.

- I'm curious to see it would be missed with more sane simple message passing
  primitives.

## Embrace the idea of the nature of message passing?

The best idea I currently have is just to have three types of message passing
primitives. Each one can seamlessly have more than one sender and recver.

- `local p = pipe([n])` if `n` is nil, the pipe is unbuffered, otherwise it has a
  buffered queue of that size. `0` indicates a limitless queue. Senders block
  if the buffer is full until there is a recver. Recvers block until there is
  an item in the buffer or there is a sender.

- `local v = value()` senders never block. Recver's block until a value has been sent.
  From then on they will return immediately with the last sent value. Sending
  `nil` will clear the value, causing future recv's to block again.

- `local b = broadcast()` senders never block. All recver's currently blocked
  will fire when a value is sent.

For backwards compatibility, maybe each method could continue to return 2
items, sender and recver, but the first item has the recver interface as well?
