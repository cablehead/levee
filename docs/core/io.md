## Hub.io

* r(no, timeout):
  returns an `io.R` to wrap the file descriptor `no`. if `timeout`
  is supplied all operations will use that for a default timeout.

* w(no, timeout):
  returns an `io.W` to wrap the file descriptor `no`. if `timeout` is supplied
  all operations will use that for a default timeout.

* rw(no, timeout):
  returns an `io.RW` to wrap the file descriptor `no`. if `timeout` is supplied
  all operations will use that for a default timeout.

* pipe(timeout):
  creates a file descriptor pair. returns `err`, `r`, `w` where `r` is an
  `io.R` and `w` is an `io.W`.

* open(name, ...):
  convenience to open the file `name` with the flags specified in `...`. e.g.
  `C.O_RDWR`. returns `err`, `io` where `io` is either an `io.R`, `io.W` or
  `io.RW` depending on the mode specified.


## Objects

### io.R

* read(buf, size):
  reads up to `size` bytes into `buf`. it will block the current green thread
  until some bytes are available unless `timeout` is reached. returns `err`,
  `n` where `n` is the number of bytes read.

* readinto(buf):
  convenience to read into a `levee.d.buffer`. ensures there's sufficient space
  to write into the buffer. returns `err`, `n`.

* reads(size):
  convenience to read and return a lua string up to `size` bytes. `size`
  defaults to 4096. returns `nil` or a string.

* stream():
  returns a Stream Object for this file descriptor. Note, mixing direct reads
  with stream usage will result in sadness.

### io.W

* write(buf, size):
  writes `size` number of bytes from `buf` to the file descriptor. if `size` is
  not provided write will it'll be attempted to be detected. `buf` can also be
  a lua string.  block the current green thread until all bytes are written, or
  an unrecoverable error occurs. returns `err`, `n` where `n` will be `size`,
  unless there was an error.

* iov(size):
  `size` is the size of the write queue. it defaults to 32.  it returns `err`,
  `sender` that you can send: lua strings; pointers whose size can be detected
  and objects that offer a :value() method. this method should return a pointer
  and a size. items sent to the queue will eventually be flushed to the file
  descriptor via writev operations. Note mixing iov use with direct writes will
  result in sadness.

* send(...):
  convenience to send multiple values to :iov(). returns `err`.

### io.RW

Offers all the methods of both an `io.R` and an `io.W`.


### Stream

A Stream is combination of an IO file descriptor and a buffer.

#### attributes

* conn:

* buf:

#### methods

* readin(n):
  read from the stream's conn to its buf. if `n` is the call will block the
  current green thread until the next successful read. otherwise this call will
  block until *at least* `n` bytes are available in the `buf` if there are
  already `n` bytes available, it returns immediately. returns `err`, `n`.

* read(buf, len):
  writes `len` bytes of this stream to `buf`. if some bytes are currently
  buffered they will be copied to `buf`. if more bytes are needed they'll then
  be read directly from stream's conn. returns `err`, `n`.

* readinto(buf, len):
  convenience to read `len` bytes into a `levee.d.buffer`. ensures there's
  sufficient space to write into the buffer. if some bytes are currently
  buffered they will be copied to `buf`. returns `err`, `n`.

* value():
  returns `buf`, `len` of the stream currently buffered

* trim(len):
  trims this stream's buf by len. if len is nil then trims the entire buf.

* take(n):
  blocks until `n` bytes are buffered, and returns them as a lua string, or
  `nil` if there was an error.

* json():
  decodes the stream using the json decoder and returns a lua table for the
  decoded json.

* chunk(n):
  create a Chunk object from this stream that's `n` bytes.


### Chunk

A Chunk is a fixed length portion of a stream which can be delegated. It offers
the same interface as it's underlying stream, however it will appear to be
closed once the size of the chunk has been exhausted.

#### attributes

* stream:
  the underlying stream

* len:
  the remaining length of the chunk

* done:
  a recv-able that will `close` when the chunk is exhausted.

#### methods

* readin(n):
  read from the stream's conn to its buf.

* value():
  returns buf, len of the stream currently buffered

* trim(len):
  trims the stream's buf by len. if len is nil then trims the entire buf. the
  chunk's len will be reduced by the actual amount trimmed. if len drops to 0
  the chunk will be marked as done.

* splice(conn):
  writes this chunk to conn and marks it as done.

* tostring():
  copies the entire chunk into a string and marks it as done. returns `nil` if
  there is an error.

* tobuffer(buf):
	convenience to read the entire chunk into a `levee.d.buffer`. if `buf` nil a
  new buffer will be created. returns `nil`, `buf` on success, `err` otherwise.

* discard():
  consumes the entire chunk with as few resources as possible and marks it as
  done.

* json():
  decodes the chunk using the json decoder and returns a lua table for the
  decoded json.
