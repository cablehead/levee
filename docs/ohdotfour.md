What's coming in Levee 0.4
==========================

Protocol Conveniences
---------------------

If you are familiar with streams with Levee, the new protocol conveniences
expand on that idea. You probably aren't though, so let's start from scratch!

The following snippet will successively read from a pipe, printing what's read,
reusing the same memory buffer for each read:

```lua
    local h = levee.Hub()

    local r, w = h.io:pipe()

    h:spawn(function() write_stuff(w) end)

    local buf = d.Buffer(4096)
    while true do
        local err = r:readinto(buf)
        if err then break end
        print(ffi.string(buf:value()))
        buf:trim()
    end
```

Levee has a concept of a stream. A stream is usually combination of an io.R
and a d.Buffer. So, a way to read additional bytes from a source and a
temporary reusable scratch pad of memory. When paired together it makes it
possible to parse an incoming stream bytes in a memory efficient way.

A stream is anything that provides the following interface:

- :readin([n])
- :value()
- :trim([n])

All of Levee's protocol decoders can work with this interface:

```lua
    local p = require("levee.p")
    local err, data = p.msgpack:decoder():stream(stream)
```

With 0.4, anything that provides an io.R interface now has a `.p` attribute
that provides this stream interface.

It's possible to register protocol conveniences that will then be available
from the `.p` attribute. All of Levee's builtin core protocols are immediately
available. As well as supporting read operations, protocol conveniences support
writes as well. There's an additional `d.Buffer` that's allocated that can be
reused to prepare bytes before they are written.

Here's how working with Msgpack looks with protocol conveniences:

```lua
    local h = levee.Hub()
    local r, w = h.io:pipe()
    local err = w.p.msgmack:write({foo = "bar"})
    local err, data = r.p.msgpack:read()
```

And here's JSON:

```lua
    local h = levee.Hub()
    local r, w = h.io:pipe()
    local err = w.p.json:write({foo = "bar"})
    local err, data = r.p.json:read()
```

There are some basic conveniences you can power up anything that offers the
stream interface. The `.p` attribute offers these methods as well:

- local err, s = r.p:tostring([len])
- local err = r.p:splice(target, [len])
- local err = r.p:save(name, [len])

HTTP is now just a Protocol Convenience!
----------------------------------------

This has a bunch of advantages. It gave us a chance to rework the API for HTTP,
and I think it's a lot easier to work with now.

Writing and reading requests and responses are now decoupled from each other.
An example use case, you could capture all HTTP requests made to your system,
and then tee those requests to a service that processes the requests for some
sort of analysis.  It doesn't make sense to need to respond, you just want to
be able to parse the stream of requests.

Note how in the following example you can work with the HTTP protocol with a
paired pipe. Using HTTP is independent of establishing a connection.

```lua
    local h = levee.Hub()
    local r, w = h.io:pipe()
    local err = w.p.http:write_request("GET", "/oh-hai")
    local err, req = r.p:http:read_request()
```
