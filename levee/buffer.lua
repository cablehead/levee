require('levee.cdef')

local ffi = require('ffi')
local Errno = require('levee.errno')

ffi.cdef[[
static const unsigned LEVEE_BUFFER_MIN_SIZE = 8192;
static const unsigned LEVEE_BUFFER_MAX_BLOCK = 65536;
struct LeveeBuffer {
	uint8_t *buf;
	uint32_t off, len, cap;
};
]]

local C = ffi.C

local Buffer = {}


function Buffer:new(hint)
	return self.allocate():ensure(hint or 0)
end


function Buffer:__tostring()
	return string.format("levee.Buffer: off=%u, len=%u, cap=%u", self.off, self.len, self.cap)
end


function Buffer:__len()
	return self.len
end


function Buffer:available()
	return self.cap - (self.off + self.len)
end


function Buffer:ensure(hint)
	local cap = self.len + hint

	if cap <= self.cap then
		-- already have enough space
		if self.len == 0 then
			-- can reclaim all space so reset offset
			self.off = 0
		elseif self:available() < hint then
			-- reclaim trimmed space and reset offset
			C.memmove(self.buf, self.buf+self.off, self.len)
			self.off = 0
		end
		return self
	end

	-- find next capacity size
	if cap <= C.LEVEE_BUFFER_MIN_SIZE then
		cap = C.LEVEE_BUFFER_MIN_SIZE
	elseif cap >= C.LEVEE_BUFFER_MAX_BLOCK then
		-- grow to nearest LEVEE_BUFFER_MAX_BLOCK size with capacity to hold hint
		cap = (((cap - 1) / C.LEVEE_BUFFER_MAX_BLOCK) + 1) * C.LEVEE_BUFFER_MAX_BLOCK;
	else
		-- grow to nearest power of 2
		cap = math.pow(2, math.ceil(math.log(cap)/math.log(2)))
	end

	local buf = C.malloc(cap)
	if buf == nil then
		Errno:error("malloc")
	end
	if self.len > 0 then
		-- only copy the subregion containing untrimmed data
		C.memcpy(buf, self.buf+self.off, self.len)
	end
	C.free(self.buf)

	-- always reset the offset back to 0
	self.buf = buf
	self.off = 0
	self.cap = cap

	return self
end


function Buffer:trim(len)
	if not len or len >= self.len then
		self.off = 0
		self.len = 0
	else
		self.off = self.off + len
		self.len = self.len - len
	end
end


function Buffer:read(sock, len)
	if not len then len = sock:available() end
	self:ensure(len)

	local read = sock:read(self.buf + self.off + self.len, len)
	if read > 0 then
		self.len = self.len + read
		return read, 0
	else
		return -1, ffi.errno()
	end
end


function Buffer:write(sock, len)
	if not len then len = self.len end
	local write = sock:write(self.buf + self.off, len)
	if write > 0 then
		self:trim(write)
	end
	return write
end


function Buffer:value()
	return self.buf + self.off, self.len
end


function Buffer:peek()
	if self.len == 0ULL then return "" end
	return ffi.string(self.buf + self.off, self.len)
end


function Buffer:take()
	local value = self:peek()
	self:trim()
	return value
end


Buffer.__index = Buffer
Buffer.allocate = ffi.metatype("struct LeveeBuffer", Buffer)

return Buffer
