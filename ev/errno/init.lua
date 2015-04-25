local ffi = require("ffi")

local types = {
	OSX     = "ev.errno.osx",
	Linux   = "ev.errno.linux",
	BSD     = "ev.errno.bsd"
}

local module = {}
local messages = {}
for k,v in pairs(require(types[ffi.os])) do
	module[k] = v[1]
	messages[v[1]] = v[2]
end

function module.message(code)
	return messages[code or ffi.errno()]
end

function module.error(msg, level)
	local no = ffi.errno()
	error(string.format("%s: %s (%d)", msg, messages[no], no), 1 + (level or 1))
end

return module

