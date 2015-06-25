
## Request


### attributes

- method
- path
- version
- headers

- response

response is a pipe used to communicate the response to send. the first send for the response is expected to be in the form:

```
    {status, headers, body}
```

- status is in the form ```{code, reason}```

- headers is a table of key, value pairs

- body can be either, a string, an integer or nil

    * if body is a string it will be used as for the response body and the
      request is complete.

    * if body is an integer it is the Content-Length of the body. If it is 0,
      then the response has no body, and the request is complete. Otherwise the
      application is expected to directly transfer the specified number of
      bytes over the request's connection. Once done, the application should
      call response:close() to indicate the response has completed.

    * if body is nil then this will be a chunked response. Each subsequent send
      on the response will describe the next chunk. Either a string or an
      integer can be sent. strings will be used as is as the next chunk.
      integers indicate the length of the next chunk, and the application is
      then responsible to directly put that many bytes over the request's
      connection. Once all chunks have been sent the application should call
      response:close() to indicate the response has completed.
