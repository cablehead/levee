# Guide

To subscribe to signals, the hub provides a `signal` method.

In this example we'll subscribe to `SIGHUP` to initiate configuration changes.

```lua

    local C = require("ffi").C
    local h = require("levee").Hub()

    local speed = 1000

    h:spawn(function()
      local hup = h:signal(C.SIGHUP)
      for _ in hup do
        speed = speed * 2
        io.write(("speed is now: %d\n"):format(speed))
      end
    end)

    io.write(("kill -HUP %d  # to change speed\n"):format(C.getpid()))

    while true do
      h:sleep(speed)
      io.write("tick\n")
    end
```
