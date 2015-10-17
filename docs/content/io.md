## API

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
