## d: Useful data structures

### Buffer

Buffer provides convenient methods to facilitate continual reuse of an array of
bytes. It's levee's workhorse data structure for streaming data in a memory
efficient way.

#### methods

* ensure(hint):
	ensure that the buffer has at least `hint` free space

* available():
	returns the amount of free space in the buffer

* trim(len):
	attempts to trim at most `len` bytes. returns the number of bytes that were
	trimmed.

* bump(len):
	bumps the buffer's value cursor `len` bytes

* slice(len):
	returns `ptr`, `len` where `ptr` is a pointer to the beginning of the buffer
	and `len` is either the `len` requested or the maximum available length of
	the current buffer, which ever is lesser.

* value():
	returns `ptr`, `len` where `ptr` is a pointer to the beginning of the buffer
	and `len` is the le length of the current buffer.

* copy(target, len):
	copies the current buffer to `target` buffer. the number of bytes copied is
	either `len` or the length of the current buffer, which ever is lesser.
	returns `n` the number of bytes actually copied.

* tail():
	returns `ptr`, `len` where `ptr` is a pointer to the first unsed byte
	available to the buffer and `len` is the amount of free space available to
	the buffer.

* freeze(len):
	locks `len` bytes of the current buffer. the buffer will now appear to begin
	*after* `len`.

* thaw():
	releases bytes previously frozen.

* peek(len):
	returns a copy of up to `len` bytes of the current buffer as a lua string.

* take(len):
	returns `len` bytes of the current buffer as a lua string and trims the
	current buffer.

* push(s):
	pushes the string `s` on to the tail of the buffer.

### Fifo

### Heap

### Set

### Bloom
