local ffi = require("ffi")
local debug = require("debug")

local types = {
	OSX     = "levee.errno.osx",
	Linux   = "levee.errno.linux",
	BSD     = "levee.errno.bsd"
}

local Errno = {}
local messages = {}
for k,v in pairs(require(types[ffi.os])) do
	Errno[k] = v[1]
	messages[v[1]] = v[2]
end

function Errno:message(no)
	return messages[no or ffi.errno()]
end

function Errno:format(msg, no)
	local no = no or ffi.errno()
	return string.format("%s: %s (%d)", msg, messages[no], no)
end

function Errno:print(msg, no)
	print(self:format(msg, no))
	print(debug.traceback():sub(18))
end

function Errno:error(msg, no, level)
	error(self:format(msg, no), 1 + (level or 1))
end

return Errno
