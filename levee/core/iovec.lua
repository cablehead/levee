local ffi = require("ffi")

local iovec = ffi.typeof("struct iovec[?]")


local Iovec_mt = {}
Iovec_mt.__index = Iovec_mt


function Iovec_mt:write(buf, len)
	assert(self.n < self.size)

	if not len then
		len = #buf
	end

	if type(buf) == "string" then
		buf = ffi.cast("char*", buf)
	end

	self.iov[self.n].iov_base = buf
	self.iov[self.n].iov_len = len

	self.len = self.len + len
	self.n = self.n + 1
end


function Iovec_mt:reset()
	self.n = 0
	self.len = 0
end


local function Iovec(size)
	local self = setmetatable({
		iov = iovec(size),
		n = 0,
		len = 0,
		size = size, }, Iovec_mt)
	return self
end


return {
	Iovec = Iovec, }
