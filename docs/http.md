# Guide


# API

## Request

### attributes

- method
- path
- version
- headers
- conn
- response

    response is a pipe used to communicate the response to send. the first send
    for the response is expected to be in the form:

    `{status, headers, body}`

    - status is in the form `{code, reason}`

    - headers is a table of key, value pairs

    - body can be either a string, an integer or nil

        * if body is a string it will be used as for the response body and the
          request is complete.

        * if body is an integer it is the Content-Length of the body. If it is
          0, then the response has no body, and the request is complete.
          Otherwise the application is expected to directly transfer the
          specified number of bytes over the request's connection. Once done,
          the application should call response:close() to indicate the response
          has completed.

        * if body is nil then this will be a chunked response. Each subsequent
          send on the response will describe the next chunk. Either a string or
          an integer can be sent. strings will be used as is as the next chunk.
          integers indicate the length of the next chunk, and the application
          is then responsible to directly put that many bytes over the
          request's connection. Once all chunks have been sent the application
          should call response:close() to indicate the response has completed.

### methods

- `sendfile(filename)`

    convenience to transfer `filename` as the response. if the file does not
    exist, or is not a regular file, a 404 status is returned. currently there
    is no sanitizing of file path.

## Response

### attributes

- code
- reason
- version
- headers

- body

    If this is a Content-Length response than body will be a `Stream` the
    application can use to process the Response body.

- chunks

    If this is a chunked response than chunks will be a pipe which will yield
    the response's chunks. Each chunk will be a `Stream`. Generally you want to
    fully consume each chunk before recv-ing the next. It's also possible to
    close .done prematurely. In this case the remaining len of the current
    chunk is preserved as a prefix for the next chunk.


### methods

- `tostring()`

    Convenience to consume the entire response body and return it as a string.

- `tobuffer([buf])`

    Convenience to stream the entire response body into a buffer. If the
    optional *buf* is not provided, a new buffer will be created and returned.

- `save(name)`

    Convenience to stream the entire response body to the given filename.

- `discard()`

    Convenience to discard the entire response body using a minimal amount of
    resources.

- `json()`

    Convenience to stream the entire response body through the json decoder.
    Returns a lua table object for the decoded json.


## Stream

*This'll likely move to be a general message / io primitive.*

A `Stream` allows a portion of a streaming socket to be delegated.

### attributes

- conn
- buf
- len
- done

### methods

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
