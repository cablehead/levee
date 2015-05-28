local ffi = require("ffi")
return require("levee.sys.poller." .. ffi.os:lower())
