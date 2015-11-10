local ffi = require("ffi")
local C = ffi.C

local message = require("levee.core.message")
local errors = require("levee.errors")

local _ = require("levee._")
local d = require("levee.d")
local p = require("levee.p")


--
-- Iovec

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


--
-- Read
--
local R_mt = {}
R_mt.__index = R_mt


function R_mt:read(buf, len, timeout)
	if self.closed then return errors.CLOSED end

	timeout = timeout or self.timeout

	local err, n = _.read(self.no, buf, len)

	if not err and n > 0 then return nil, n end
	if (err and not err.is_system_EAGAIN) or self.r_error or n == 0 then
		self:close()
		return errors.CLOSED
	end

	local err, sender, ev = self.r_ev:recv(timeout)
	if err then return err end
	if ev < 0 then self.r_error = true end
	return self:read(buf, len, timeout)
end


function R_mt:readinto(buf, timeout)
	-- ensure we have *some* space to read into
	buf:ensure(buf.cap / 2 < 65536ULL and buf.cap / 2 or 65536ULL)
	local ptr, len = buf:tail()
	local err, n = self:read(ptr, len, timeout)
	if err then return err end
	if n > 0 then buf:bump(n) end
	return err, n
end


function R_mt:reads(len)
	len = len or 4096
	local buf = ffi.new("char[?]", len)
	local err, n = self:read(buf, len)
	if err then return end
	return ffi.string(buf, n)
end


function R_mt:stream()
	return Stream(self)
end


function R_mt:close()
	if self.closed then
		return errors.CLOSED
	end

	self.closed = true
	self.hub:unregister(self.no, true)
	self.hub:continue()
	return
end


--
-- Write
--
local W_mt = {}
W_mt.__index = W_mt


function W_mt:write(buf, len)
	if self.closed then return errors.CLOSED end

	if not len then
		len = #buf
	end

	if type(buf) == "string" then
		buf = ffi.cast("char*", buf)
	end

	local sent = 0

	while true do
		local err, n = _.write(self.no, buf + sent, len - sent)

		if err and not err.is_system_EAGAIN then
			self:close()
			return err
		end

		if err or n < 0 then n = 0 end
		sent = sent + n
		if sent == len then break end
		local err = self.w_ev:recv()
		if err then
			self:close()
			return err
		end
	end

	self.hub:continue()
	return nil, len
end


function W_mt:writev(iov, n)
	if self.closed then return errors.CLOSED end

	local len
	local i, total = 0, 0

	while true do
		while true do
			len = C.writev(self.no, iov[i], n - i)
			if len > 0 then break end
			local err = errors.get(ffi.errno())
			if not err.is_system_EAGAIN then
				self:close()
				return err
			end
			self.w_ev:recv()
		end

		total = total + len

		while true do
			if iov[i].iov_len > len then break end
			len = len - iov[i].iov_len
			i = i + 1
			if i == n then
				assert(len == 0)
				self.hub:continue()
				return nil, total
			end
		end

		if len > 0 then
			iov[i].iov_base = iov[i].iov_base + len
			iov[i].iov_len = iov[i].iov_len - len
		end
	end
end


function W_mt:iov(size)
	if self.closed then return errors.CLOSED end

	if not self.iovec then
		size = size or 32

		local q
		self.iovec, q = self.hub:stalk(size)

		-- TODO: eww, this isn't right
		self.iovec.empty = q.empty
		self.empty = q.empty

		self.hub:spawn(function()
			local iov = Iovec(size)

			while true do
				local err = q:recv()
				if err then return end

				local num = #q
				for s in q:iter() do
					-- TODO - eep
					if s.value then
						iov:write(s:value())
					else
						iov:write(s)
					end
				end

				local err, n = self:writev(iov.iov, iov.n)
				if err then
					self:close()
					return
				end

				iov:reset()
				q:remove(num)
			end
		end)
	end

	return nil, self.iovec
end


function W_mt:send(...)
	local err, iov = self:iov()
	if err then return err end
	local arg = {...}
	for i = 1, #arg do
		local err = iov:send(arg[i])
		if err then return err end
	end
end


function W_mt:close()
	if self.closed then
		return errors.CLOSED
	end

	self.closed = true
	if self.iovec then self.iovec:close() end
	self.hub:unregister(self.no, false, true)
	self.hub:continue()
	return
end


--
-- Read / Write
--
local RW_mt = {}
RW_mt.__index = RW_mt


RW_mt.read = R_mt.read
RW_mt.reads = R_mt.reads
RW_mt.readinto = R_mt.readinto
RW_mt.stream = R_mt.stream
RW_mt.write = W_mt.write
RW_mt.writev = W_mt.writev
RW_mt.iov = W_mt.iov
RW_mt.send = W_mt.send


function RW_mt:close()
	if self.closed then
		return
	end

	self.closed = true
	self.hub:unregister(self.no, true, true)
	self.hub:continue()
	return true
end


--
-- Stream

-- A Stream is combination of an io file descriptor and a buffer

local Stream_mt = {}
Stream_mt.__index = Stream_mt


function Stream_mt:__tostring()
	return ("levee.Stream: buffered=%s"):format(#self.buf)
end


function Stream_mt:readin(n)
	if not n then
		return self.conn:readinto(self.buf)
	end

	while #self.buf < n do
		local err, n = self.conn:readinto(self.buf)
		if err then return err end
	end

	return nil, n
end


function Stream_mt:read(buf, len, timeout)
	local togo = len

	if #self.buf > 0 then
		local n = self.buf:copy(buf, togo)
		self.buf:trim(n)
		togo = togo - n
	end

	while togo > 0 do
		local err, n = self.conn:read(buf + (len -togo), togo, timeout)
		if err then return err end
		togo = togo - n
	end

	return nil, len
end


function Stream_mt:readinto(buf, len, timeout)
	buf:ensure(len)
	local err, n = self:read(buf:tail(), len, timeout)
	if err then return err end
	buf:bump(n)
	return nil, n
end


function Stream_mt:trim(len)
	return self.buf:trim(len)
end


function Stream_mt:value()
	return self.buf:value()
end


function Stream_mt:take(n)
	if n then
		local err, n = self:readin(n)
		if err then return end
	end
	return self.buf:take(n)
end


function Stream_mt:json()
	return p.json.decoder():stream(self)
end


function Stream_mt:chunk(len)
	return Chunk(self, len)
end


function Stream(conn)
	local self = setmetatable({}, Stream_mt)
	self.conn = conn
	self.buf = d.buffer(4096)
	return self
end


--
-- Chunk

-- A Chunk is a portion of a stream

local Chunk_mt = {}
Chunk_mt.__index = Chunk_mt


function Chunk_mt:__len()
	return self.len
end


function Chunk_mt:readin(n)
	return self.stream:readin(n)
end


function Chunk_mt:value()
	return self.stream.buf:slice(self.len)
end


function Chunk_mt:trim(n)
	if n then
		assert(n <= self.len)
	else
		n = self.len
	end
	local n = self.stream:trim(n)
	self.len = self.len - n
	if self.len == 0 then
		self.done:close()
	end
	return n
end


function Chunk_mt:splice(conn)
	local n = self.len
	while self.len > 0 do
		local err = self:readin(1)
		if err then return err end
		local err, n = conn:write(self:value())
		if err then return err end
		self:trim()
	end
	return nil, n
end


function Chunk_mt:discard()
	local n = self.len
	while self.len > 0 do
		local err = self:readin(1)
		if err then return err end
		self:trim()
	end
	return nil, n
end


function Chunk_mt:json()
	return p.json.decoder():stream(self)
end


function Chunk_mt:tobuffer(buf)
	buf = buf or d.buffer()
	local err, n = self.stream:readinto(buf, self.len)
	if err then return err end
	self.len = 0
	self.done:close()
	return nil, buf
end


function Chunk_mt:tostring()
	local s = self.stream:take(self.len)
	self.len = 0
	self.done:close()
	return s
end


function Chunk(stream, len)
	local self = setmetatable({}, Chunk_mt)
	self.hub = stream.conn.hub
	self.stream = stream
	self.len = len
	-- TODO:
	self.done = message.Pair(self.hub:value())
	return self
end

--
-- IO module interface
--
local IO_mt = {}
IO_mt.__index = IO_mt


function IO_mt:r(no, timeout)
	local m = setmetatable({hub = self.hub, no = no, timeout=timeout}, R_mt)
	m.r_ev = self.hub:register(no, true)
	return m
end


function IO_mt:w(no, timeout)
	local m = setmetatable({hub = self.hub, no = no, timeout=timeout}, W_mt)
	local _
	_, m.w_ev = self.hub:register(no, false, true)
	return m
end


function IO_mt:rw(no, timeout)
	local m = setmetatable({hub = self.hub, no = no, timeout=timeout}, RW_mt)
	m.r_ev, m.w_ev = self.hub:register(no, true, true)
	return m
end


function IO_mt:pipe(timeout)
	local err, r, w = _.pipe()
	if err then return err end
	_.fcntl_nonblock(r)
	_.fcntl_nonblock(w)
	return nil, self:r(r, timeout), self:w(w, timeout)
end


function IO_mt:open(name, ...)
	local err, no, mode = _.open(name, ...)

	if bit.band(C.O_WRONLY, mode) > 0 then
		return nil, self:w(no)
	end

	if bit.band(C.O_RDWR, mode) > 0 then
		return nil, self:rw(no)
	end

	return nil, self:r(no)
end


IO_mt.iovec = Iovec


return function(hub)
	return setmetatable({hub = hub}, IO_mt)
end
