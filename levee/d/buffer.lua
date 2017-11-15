local ffi = require('ffi')
local C = ffi.C

local _ = require("levee._.syscalls")


local errors = require("levee.errors")


local Butt_mt = {}
Butt_mt.__index = Butt_mt


function Butt_mt:__len()
	return #self.buf - self.off
end


function Butt_mt:peek(off, len)
	return ffi.string(self:value(off, len))
end


function Butt_mt:value(off, len)
	if not len then
		len = off
		off = 0
	end
	return self.buf:value(self.off+off, len or true)
end


function Butt_mt:trim(n)
	local limit = #self

	if not n or n >= limit then
		self.buf.len = self.buf.len - limit
		return limit
	end

	local start = self.buf.buf + self.buf.off + self.off
	C.memmove(start, start + n, limit - n)
	self.buf.len = self.buf.len - n
	return n
end


function Butt_mt:ensure(...)
	return self.buf:ensure(...)
end


function Butt_mt:write(...)
	return self.buf:write(...)
end


function Butt_mt:tail(...)
	return self.buf:tail(...)
end


function Butt_mt:bump(...)
	return self.buf:bump(...)
end


local function Butt(buf, off)
	return setmetatable({buf=buf, off=off}, Butt_mt)
end


local Buffer_mt = {}
Buffer_mt.__index = Buffer_mt


function Buffer_mt:__tostring()
	return string.format(
		"levee.d.Buffer: sav=%u, off=%u, len=%u, cap=%u",
		self.sav, self.off, self.len, self.cap)
end


function Buffer_mt:__len()
	return self.len
end


function Buffer_mt:truncate()
	if self.off > 0 then
		C.memmove(self.buf, self.buf+self.off, self.len)
		self.off = 0
	end
end


function Buffer_mt:ensure(hint)
	if not hint then
		-- ensure we have *some* space to read into
		hint = self.cap / 2 < 65536ULL and self.cap / 2 or 65536ULL
	end

	local cap = self.sav + self.len + hint

	if cap <= self.cap then
		-- already have enough space
		if self.len == 0 then
			-- can reclaim all space so reset offset
			self.off = 0
		elseif self:available() < hint then
			-- reclaim trimmed space and reset offset
			self:truncate()
		end
		return self
	end

	-- find next capacity size
	if cap <= C.LEVEE_BUFFER_MIN_SIZE then
		cap = C.LEVEE_BUFFER_MIN_SIZE
	elseif cap >= C.LEVEE_BUFFER_MAX_BLOCK then
		-- grow to nearest LEVEE_BUFFER_MAX_BLOCK size with capacity to hold hint
		cap = (
			((cap - 1) / C.LEVEE_BUFFER_MAX_BLOCK) + 1) * C.LEVEE_BUFFER_MAX_BLOCK
	else
		-- grow to nearest power of 2
		cap = math.pow(2, math.ceil(math.log(cap)/math.log(2)))
	end

	local sav = self.sav
	if sav > 0 then self:thaw() end

	local pg = _.pagesize
	local oldcap = self.cap

	if oldcap > 0 then
		local err = _.mprotect(self.buf+oldcap, pg, "r+")
		oldcap = oldcap + pg
	end

	local err, buf = _.mremap_anon(self.buf, self.cap, cap + pg)
	if err then error(tostring(err)) end
	_.mprotect(buf+cap, pg, "r")

	-- always reset the offset back to 0
	self.buf = buf
	self.off = 0
	self.cap = cap

	if sav > 0 then self:freeze(sav) end

	return self
end


function Buffer_mt:available()
	return self.cap - (self.off + self.len + self.sav)
end


function Buffer_mt:trim(len)
	if not len or len >= self.len then
		local ret = self.len
		self.off = 0
		self.len = 0
		return ret
	end

	self.off = self.off + len
	self.len = self.len - len
	return len
end


function Buffer_mt:bump(len)
	self.len = self.len + len
end


function Buffer_mt:slice(len)
	return self.buf + self.off, len < self.len and len or self.len
end


function Buffer_mt:value(off, len)
	if len == true then
		len = self.len
	end

	if not len then
		len = off
		off = 0
	else
		if off > self.len then off = self.len end
	end

	if not len then
		len = self.len - off
	else
		if len > self.len - off then len = self.len - off end
	end
	return self.buf + self.off + off, len
end


function Buffer_mt:copy(tgt, n)
	local buf, len = self:value()
	if len == 0 then return 0 end
	if n > len then n = len end
	C.memcpy(tgt, buf, n)
	return n
end


function Buffer_mt:move(tgt, n)
	local n = self:copy(tgt, n)
	if n > 0 then self:trim(n) end
	return n
end


function Buffer_mt:tail()
	return self.buf + self.off + self.len, self:available()
end


function Buffer_mt:freeze(len)
	assert(len <= self.len)
	assert(self.sav == 0)
	self:truncate()
	self.sav = len
	self.len = self.len - len
	self.buf = self.buf + len
end


function Buffer_mt:thaw()
	assert(self.sav > 0)
	self:truncate()
	self.len = self.len + self.sav
	self.buf = self.buf - self.sav
	self.sav = 0
end


function Buffer_mt:protect()
	_.mprotect(self.buf, self.cap, "r")
end


function Buffer_mt:unprotect()
	_.mprotect(self.buf, self.cap, "r+")
end


function Buffer_mt:peek(len)
	if len then
		len = len < self.len and len or self.len
	else
		len = self.len
	end
	if len == 0ULL then return "" end
	return ffi.string(self.buf + self.off, len)
end


function Buffer_mt:take(len)
	local value = self:peek(len)
	self:trim(#value)
	return value
end


function Buffer_mt:write(buf, len)
	len = len or #buf
	self:ensure(len)
	ffi.copy(self:tail(), buf, len)
	self:bump(len)
end


Buffer_mt.push = Buffer_mt.write


function Buffer_mt:writeinto_iovec(iov)
	iov:writeraw(self:value())
end


function Buffer_mt:butt(off)
	return Butt(self, off)
end


local function cleanup(buf)
	_.munmap(buf.buf, buf.cap + _.pagesize)
	C.free(buf)
end


local mt = ffi.metatype("LeveeBuffer", Buffer_mt)


local M_mt = {}
M_mt.__index = M_mt


function M_mt.__call(M, hint)
	local buf = C.malloc(ffi.sizeof(mt))
	buf = ffi.cast("LeveeBuffer*", buf)
	buf = ffi.gc(buf, cleanup)
	buf.buf = nil
	buf.off = 0
	buf.len = 0
	buf.cap = 0
	buf.sav = 0
	buf:ensure(hint)
	return buf
end


function M_mt.from_ptr(M, buf)
	buf = ffi.cast("LeveeBuffer*", buf)
	buf = ffi.gc(buf, cleanup)
	return buf
end


return setmetatable({}, M_mt)
