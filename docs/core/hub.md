

#### coroutines

* \_coresume(`co`, `err`, `value`):
  switch context away from the hub's main event loop to a green thread. `co` is
  the thread to resume. `err` is a potential error. `value` is the value to
  give to the thread.

* \_coyield(co, err, value):
  yield context from a green thread back to the hub's main event loop. `co` is
  an optional coroutine to switch to immediately instead of continuing to
  process the event loop's queue, in which case `err` is a potential error and
  `value` is the value to give to the thread. returns `err`, `value` when this
  green thread is resumed.

* continue():
  yield from the current green thread, to be resumed after 1 tick of the event
  loop.

* switch_to(co, err, value):
  yield from the current green thread and switch immediately to `co` with `err`
  and `value`. the current green thread will be resumed after 1 tick of the
  event loop.

* pause(ms):
  if `ms` is not provided this simply yields the current thread. otherwise, a
  timeout `ms` milliseconds in the future will be set up.  returns `err`,
  `value` when this green thread is resumed.  if the thread isn't resumed
  before the timeout `err` will be a *levee_timeout*.

* resume(co, err, value):
  schedule the thread `co` to be resumed with `err` and `value`. returns
  immediately.

* sleep(ms):
  suspends the current green thread until at least `ms` milliseconds in the
  future, when it will be resumed.

* spawn(f, a)
  spawns and queues to run the callable `f` as a new green thread. the optional
  argument `a` will be passed to the callable. the current thread will yield to
  be resumed after 1 tick of the event loop.

* spawn_later(ms f)
  schedules the callable `f` to run at least `ms` milliseconds in the future,
  in a new green thread. note an optional argument isn't available.

#### poller

* register(no, r, w):
  registers file descriptor `no` with the poller. returns `r`, `w` where `r`
  and `w` are either nil, or a `FDState`, depending on whether in calling
  arguments `r` and `w` are true or fale.

* unregister(no):
  marks file descriptor `no` to be closed and removed from the poller.

#### signal

* signal(...):
  subscribe to one or more signals.

#### thread

* thread:call(f, ...):
  runs `f` in a new thread with arguments `...`. returns a `recver` which will
  yield the return values of `f`. `f` is expected to return `err`, `value`

* thread:spawn(f):
  spawns `f` in a new thread and returns a `channel` to send and recv data into
  the thread. `f` will be passed a `hub` as an arugment which is it's own event
  loop. `hub` will have an additional attribute `parent` which is a channel to
  send and recv data back to the parent thread.

#### process

* process:spawn(name, options):
  `name` is the name of a command to run. `options` is a table of options:

    * argv:
      arguments for the command

    * io:

      - STDIN:
        how to treat the child processes STDIN. by default STDIN will be
        captured, available as a stream on p.stdin. if this option is a number
        than the child's STDIN will be mapped to that file descriptor.

      - STDOUT:
        how to treat the child processes STDOUT. by default STDOUT will be
        captured, available as a stream on p.stdout. if this option is a number
        than the child's STDOUT will be mapped to that file descriptor.

  returns a Process object

#### tcp

* tcp:connect(port, host):

* tcp:listen(port, host):

### objects

#### `FDState`

* recv(ms):
  blocks until the file descriptor is in a ready state or until `ms`
  milliseconds have passed. returns `err`, `value` where `err` indicates
  whether a timeout occurred and `value` is either 1 or -1. -1 indicates that
  in addition to the file descriptor potentially being ready (buffered bytes),
  the file descriptor is closed.

#### `Process`

##### attributes

* pid:
  the processes pid

* stdin, stdout:
  unless io.STDIN or io.STDOUT are specified as spawn options, these attributes
  will be present.

* done: recv-able to indicate the process has completed.

* exit_code:
  once the process completes this attribute will be present to indicate the
  processes exit code.

* exit_sig:
  once the process completes this attribute will be present to indicate the
  processes exit signal.

##### methods

* running():
  is the process still running?

* kill(signal):
  send `signal` to the process. defaults to SIGTERM.
