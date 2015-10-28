

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

* switch_to(co, value):
	yield from the current green thread and switch immediately to `co` with
	`value`. the current green thread will be resumed after 1 tick of the event
	loop.

* pause(ms):
	if `ms` is not provided this simply yields the current thread. otherwise, a
	timeout `ms` milliseconds in the future will be set up. if the thread isn't
	resumed before this timeout it'll be resumed with a TIMEOUT error.

* sleep(ms):
	suspends the current green thread until at least `ms` milliseconds in the
	future, when it will be resumed.

* spawn(f, a)
	spawns and queues to run the callable `f` as a new green thread. the optional
	argument `a` will be passed to the callable. the current thread will yield to
	be resumed after 1 tick of the event loop.

* spawn_later(ms f, a)
	schedules the callable `f` to run with the optional argument `a` at least
	`ms` milliseconds in the future, in a new green thread.
