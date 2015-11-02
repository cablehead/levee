## Hub.io

* r(no, timeout):
	returns a readable IO object to wrap the file descriptor `no`. if `timeout`
	is supplied all operations will use that for a default timeout.

* w(no, timeout):
	returns a writeable IO object to wrap the file descriptor `no`. if `timeout`
	is supplied all operations will use that for a default timeout.

* pipe(timeout):
	returns `err`, `r`, `w` where `r` is a readable IO object and `w` is a
	writeable IO object.

## Objects

### Readable IO

* read(buf, size, timeout):
	reads up to `size` bytes into `buf`. it will block the current green thread
	until some bytes are available unless `timeout` is reached. returns `err`,
	`n` where `n` is the number of bytes read.

* readinto(buf, timeout):
	convenience to read into a `levee.d.buffer`. ensures there's sufficient space
	to write into the buffer. returns `err`, `n`.

### Writable IO

* write(buf, size):
	writes `size` number of bytes from `buf` to the file descriptor. if `size` is
	not provided write will it'll be attempted to be detected. `buf` can also be
	a lua string.  block the current green thread until all bytes are written, or
	an unrecoverable error occurs. returns `err`, `n` where `n` will be `size`,
	unless there was an error.


### Stream

A Stream is combination of an IO file descriptor and a buffer.

#### attributes

- conn
- buf
- len
- done

#### methods

- `readin()`:

    read from the stream's conn to its buf.

- `value()`

    returns buf, len of the stream currently buffered

- `trim(len)`

    trims this stream's buf by len. if len is nil then trims the entire buf.
    the stream's len will be reduced by the actual amount trimmed. if len drops
    to 0 the stream will be marked as done.

- `splice(conn)`

    writes this stream to conn and marks it as done.

- `tostring()`

    copies the entire stream into a string and marks it as done.

- `discard()`

    consumes the entire stream with as few resources as possible and marks it
    as done.

- `json()`

    decodes the stream using the json decoder and returns a lua table for the
    decoded json.
