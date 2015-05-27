local ffi = require("ffi")
return require("levee.poller." .. ffi.os:lower())
