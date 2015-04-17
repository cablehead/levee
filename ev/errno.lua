local ffi = require("ffi")

local types = {
	OSX     = "ev.errno.osx",
	Linux   = "ev.errno.linux",
	BSD     = "ev.errno.bsd"
}

local codes = {}
local messages = {}
for k,v in pairs(require(types[ffi.os])) do
	codes[k] = v[1]
	messages[v[1]] = v[2]
end

function codes.message(code)
	return messages[code or ffi.errno()]
end

return codes

