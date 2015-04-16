local ffi = require('ffi')
ffi.cdef[[
long read(int fildes, void *buf, size_t nbyte);
]]
local ev = require('ev')

local loop = ev.loop()

loop:poll(0, function(avail)
	local buf = ffi.new('uint8_t[?]', avail)
	local n = ffi.C.read(0, buf, avail)
	print("> " .. ffi.string(buf, n))
end)

loop:run()

