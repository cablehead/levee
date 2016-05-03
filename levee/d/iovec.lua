local ffi = require('ffi')
local C = ffi.C

local errors = require("levee.errors")


local iovec_size = ffi.sizeof("struct iovec")
local iovecp = ffi.typeof("struct iovec *")


local Iovec_mt = {}
Iovec_mt.__index = Iovec_mt


function Iovec_mt:__tostring()
	return string.format(
		"levee.d.Iovec: n=%d, len=%d, size=%d",
		tonumber(self.n), tonumber(self.len), tonumber(self.size))
end


function Iovec_mt:__len()
	return self.len
end


function Iovec_mt:write(val, len)
	if type(val) == "cdata" or val.writeinto_iovec then
		val:writeinto_iovec(self)
		return
	end

	if val.value then
		val, len = val:value()
	end

	self:writeraw(val, len)
end


function Iovec_mt:writeraw(val, len)
	if self.n == self.size then
		self:ensure(1)
	end

	if self.n == self.size then
		self:ensure(1)
	end

	if not len then
		len = #val
	end

	if len == 0 then
		return
	end

	if type(val) == "string" then
		val = ffi.cast("char *", val)
	end

	self.iov[self.n].iov_base = val
	self.iov[self.n].iov_len = len

	self.len = self.len + len
	self.n = self.n + 1
end


function Iovec_mt:writeinto_iovec(iov)
	iov:ensure(self.n)
	C.memcpy(self.iov + self.n, iov.iov, iovec_size * iov.n)
	iov:bump(iov.n)
end


function Iovec_mt:ensure(n)
	local size = self.n + n
	if size <= self.size then return end
	size = math.pow(2, math.ceil(math.log(tonumber(size))/math.log(2)))
	local iov = ffi.cast(iovecp, C.malloc(iovec_size * size))
	if iov == nil then error(tostring(errors.get(ffi.errno()))) end
	C.memcpy(iov, self.iov, ffi.sizeof(iov[0]) * self.n)
	self.iov = ffi.gc(iov, C.free)
	self.size = size
end


function Iovec_mt:value()
	return self.iov, self.n
end


function Iovec_mt:tail()
	return self.iov + self.n, self.size - self.n
end


function Iovec_mt:bump(n, len)
	if not len then
		len = 0
		for i=self.n,self.n+n-1 do
			len = len + self.iov[i].iov_len
		end
	end
	self.n = self.n + n
	self.len = self.len + len
end


function Iovec_mt:reset()
	self.n = 0
	self.len = 0
end


return function(size)
	local self = setmetatable({
		iov = nil,
		n = 0,
		len = 0,
		size = 0, }, Iovec_mt)
	if size then self:ensure(size) end
	return self
end
