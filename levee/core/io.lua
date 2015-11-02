local ffi = require("ffi")
local C = ffi.C


local errors = require("levee.errors")
local d = require("levee.d")
local _ = require("levee._")


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
		return err or errors.CLOSED
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
	local n, err = self:read(ptr, len, timeout)

	if n == constants.TIMEOUT then return n end

	if n > 0 then
		buf:bump(n)
	end

	return n, err
end


function R_mt:reads(len)
	len = len or 4096
	local buf = ffi.new("char[?]", len)
	local n, err = self:read(buf, len)
	if n < 0 then
		return nil, err
	end
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

		-- TODO: eagain
		if err then
			self:close()
			return err
		end

		if n < 0 then n = 0 end
		sent = sent + n
		if sent == len then break end
		local err = self.w_ev:recv()
		if err then return err end
	end

	self.hub:continue()
	return nil, len
end


function W_mt:writev(iov, n)
	if self.closed then return -1, errno["EBADF"] end

	local len
	local i, total = 0, 0

	while true do
		while true do
			len = C.writev(self.no, iov[i], n - i)
			if len > 0 then break end

			local err = ffi.errno()
			if err ~= errno["EAGAIN"] then
				self:close()
				return len, err
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
				return total
			end
		end

		if len > 0 then
			iov[i].iov_base = iov[i].iov_base + len
			iov[i].iov_len = iov[i].iov_len - len
		end
	end
end


function W_mt:iov(size)
	if self.closed then return -1, errno["EBADF"] end

	if not self.iovec then
		size = size or 32
		self.iovec = self.hub:stalk(size)

		self.hub:spawn(function()
			local q = self.iovec
			local iov = iovec.Iovec(size)

			while true do
				if not q:recv() then return end

				local n = #q
				for s in q:iter() do
					-- TODO - eep
					if s.value then
						iov:write(s:value())
					else
						iov:write(s)
					end
				end

				local rc = self:writev(iov.iov, iov.n)
				if rc <= 0 then
					self:close()
					return
				end

				iov:reset()
				q:remove(n)
			end
		end)
	end

	return self.iovec
end


function W_mt:close()
	if self.closed then
		return
	end

	self.closed = true
	if self.iovec then self.iovec:close() end
	self.hub:unregister(self.no, false, true)
	self.hub:continue()
	return true
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
		local ok, err = self.conn:readinto(self.buf)
		if ok < 0 then return ok, err end
	end

	return n
end


function Stream_mt:read(buf, len, timeout)
	local togo = len

	if #self.buf > 0 then
		local n = self.buf:copy(buf, len)
		self.buf:trim(n)
		togo = togo - n
		if togo == 0 then return len end
	end

	local n, err = self.conn:read(buf, togo, timeout)
	if n == constants.TIMEOUT then return n end
	if n < 0 then return n, err end
	return len
end


function Stream_mt:trim(len)
	return self.buf:trim(len)
end


function Stream_mt:value()
	return self.buf:value()
end


function Stream_mt:take_s(n)
	if n then
		local ok, err = self:readin(n)
		if ok < 0 then return ok, err end
	end
	return self.buf:take_s(n)
end


function Stream_mt:chunk(len)
	return Chunk(self, len)
end


function Stream(conn)
	local self = setmetatable({}, Stream_mt)
	self.conn = conn
	self.buf = buffer(4096)
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


function Chunk_mt:tostring()
	local s = self.stream:take_s(self.len)
	self.done:close()
	return s
end


function Chunk(stream, len)
	local self = setmetatable({}, Chunk_mt)
	self.hub = stream.conn.hub
	self.stream = stream
	self.len = len
	self.done = self.hub:pipe()
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


return function(hub)
	return setmetatable({hub = hub}, IO_mt)
end
