local ffi = require("ffi")
local C = ffi.C

local message = require("levee.core.message")
local errors = require("levee.errors")

local _ = require("levee._")
local d = require("levee.d")
local p = require("levee.p")


local MIN_SPLICE_SIZE = 4 * _.pagesize


--
-- Read
--
local R_mt = {}
R_mt.__index = R_mt


function R_mt:read(buf, len)
	if self.closed then return errors.CLOSED end

	local err, n = _.read(self.no, buf, len)

	if not err and n > 0 then return nil, n end
	if (err and not err.is_system_EAGAIN) or self.r_error or n == 0 then
		self:close()
		return errors.CLOSED
	end

	local err, sender, ev = self.r_ev:recv(self.timeout)
	if err then return err end
	if ev < 0 then self.r_error = true end
	return self:read(buf, len)
end


function R_mt:readn(buf, n, len)
	if self.closed then return errors.CLOSED end

	len = len or n
	local read = 0

	while read < n do
		local err, c = self:read(buf + read, len - read)
		if err then return err end
		read = read + c
	end

	return nil, read
end


function R_mt:readinto(buf, n)
	local err, read

	if n then
		local needed = n - #buf
		if needed <= 0 then return end
		buf:ensure(needed)
		local ptr, len = buf:tail()
		err, read = self:readn(ptr, needed, len)

	else
		buf:ensure()
		err, read = self:read(buf:tail())
	end

	if err then return err end
	buf:bump(read)
end


function R_mt:reads(len)
	len = len or 4096
	local buf = ffi.new("char[?]", len)
	local err, n = self:read(buf, len)
	if err then return end
	return ffi.string(buf, n)
end


function R_mt:sendfile(to, len, off)
	local remain = len
	off = off or 0

	while remain > 0 do
		local err, n = _.sendfile(self.no, to.no, remain, off)
		if err and not err.is_system_EAGAIN then return err end
		if err or n < 0 then n = 0 end

		off = off + n
		remain = remain - n

		local err, ev = to.w_ev:recv()
		if err then return err end
	end

	return nil, len
end


if _.splice then
	function R_mt:_splice(to, len)
		if self.closed then return errors.CLOSED end

		local err, n = _.splice(self.no, to.no, len)

		if not err and n > 0 then return nil, n end
		if (err and not err.is_system_EAGAIN) or self.r_error or n == 0 then
			self:close()
			return errors.CLOSED
		end

		local err, sender, ev = self.r_ev:recv(self.timeout)
		if err then return err end
		if ev < 0 then self.r_error = true end
		return self:_splice(to, len)
	end
end


if _.tee then
	function R_mt:_tee(to, len)
		if self.closed then return errors.CLOSED end

		local err, n = _.tee(self.no, to.no, len)

		if not err and n > 0 then return nil, n end
		if (err and not err.is_system_EAGAIN) or self.r_error or n == 0 then
			self:close()
			return errors.CLOSED
		end

		local err, ev = self.t_ev:recv(self.timeout)
		if err then return err end
		if ev < 0 then self.r_error = true end
		return self:_tee(to, len)
	end
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


function R_mt:stat()
	return _.fstat(self.no)
end


--
-- Write
--
local W_mt = {}
W_mt.__index = W_mt
W_mt.stat = R_mt.stat


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
			local iov = d.Iovec(size)

			while true do
				local err = q:recv()
				if err then return end

				local num = #q
				for s in q:iter() do
					iov:write(s)
				end

				local err, n = self:writev(iov:value())
				if err then
					q.fifo:remove(#q.fifo)   -- this should be handled in stalk
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
	if self.closed then
		return errors.CLOSED
	end

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
	if self.iovec then
		self.iovec:close()
		self.iovec.empty:send(true)
	end
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
RW_mt.readn = R_mt.readn
RW_mt.reads = R_mt.reads
RW_mt.readinto = R_mt.readinto
RW_mt.stream = R_mt.stream
RW_mt._splice = R_mt._splice
RW_mt._tee = R_mt._tee
RW_mt.stat = R_mt.stat
RW_mt.write = W_mt.write
RW_mt.writev = W_mt.writev
RW_mt.iov = W_mt.iov
RW_mt.send = W_mt.send


function RW_mt:close()
	if self.closed then
		return
	end

	self.closed = true
	if self.iovec then
		self.iovec:close()
		self.iovec.empty:send(true)
	end
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
	return self.conn:readinto(self.buf, n)
end


function Stream_mt:read(buf, len)
	local n = self.buf:move(buf, len)
	if n > 0 then return nil, n end
	local err, n = self.conn:read(buf + n, len - n)
	if err then return err end
	return nil, n
end


function Stream_mt:readn(buf, n, len)
	len = len or n
	local read = self.buf:move(buf, n)
	if read < n then
		local err, more = self.conn:readn(buf + read, n - read, len - read)
		if err then return err end
		read = read + more
	end

	return nil, read
end


function Stream_mt:readinto(buf, n)
	local err, read

	if n then
		local needed = n - #buf
		if needed <= 0 then return end
		buf:ensure(needed)
		local ptr, len = buf:tail()
		err, read = self:readn(ptr, needed)

	else
		buf:ensure()
		err, read = self:read(buf:tail())
	end

	if err then return err end
	buf:bump(read)
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


function Stream_mt:json_decoder()
	if not self._json_decoder then self._json_decoder = p.json.decoder() end
	return self._json_decoder
end


function Stream_mt:json()
	return self:json_decoder():stream(self)
end


function Stream_mt:line(delim)
	return p.line.stream(self, delim)
end


function Stream_mt:chunk(len)
	return Chunk(self, len)
end


function Stream(conn)
	local self = setmetatable({}, Stream_mt)
	self.conn = conn
	self.buf = d.Buffer(4096)
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
	return self.stream:json_decoder():stream(self)
end


function Chunk_mt:tobuffer(buf)
	buf = buf or d.Buffer()
	local err = self.stream:readinto(buf, self.len + #buf)
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


--
-- Splice

function Chunk_mt:_splice(target)
	local n = self.len

	while self.len > 0 do
		local err = self:readin(1)
		if err then return err end
		local err = target:write(self:value())
		self:trim()
		if err then return err end
	end

	return nil, n
end


function Chunk_mt:_splice_0copy(target)
	local len = self.len

	local buf, buflen = self:value()
	if self.len - buflen < MIN_SPLICE_SIZE then
		return self:_splice(target)
	end

	-- transfer any pending bytes from the buffer
	if buflen > 0 then
		local err = target:write(buf, buflen)
		if err then return err end
		self:trim()
	end

	local r, w = self.hub.io:pipe()
	local source = self.stream.conn

	-- wire splice r, w pairs' evs together
	w.w_ev.set = function(self, ...)
		source.r_ev:set(...)
	end

	local target_w_ev_set = target.w_ev.set  -- save target's w_ev
	target.w_ev.set = function(self, ...)
		r.r_ev:set(...)
	end

	local err, rn, wn
	while self.len > 0 do
		err, rn = source:_splice(w, self.len)
		if err then goto cleanup end

		self.len = self.len - rn

		while rn > 0 do
			err, wn = r:_splice(target, rn)
			if err then goto cleanup end
			rn = rn - wn
		end
	end

	::cleanup::
	-- restore target and temp w's w_ev
	target.w_ev.set = target_w_ev_set
	w.w_ev.set = target_w_ev_set
	r:close()
	w:close()

	if err then return err end

	self.len = 0
	self.done:close()
	return nil, len
end


if _.splice then
	Chunk_mt.splice = Chunk_mt._splice_0copy
else
	Chunk_mt.splice = Chunk_mt._splice
end


--
-- Tee


function Chunk_mt:_tee_once(spawned, ...)
	local targets = {...}

	local buf, len = self:value()

	for i = 1, #targets do
		local err = targets[i]:write(buf, len)
		if err then return err end
	end

	if spawned then
		local chunk = Chunk(self.stream, len)
		chunk.tee = nil
		spawned:send(chunk)
		chunk.done:recv()
		assert(chunk.len == 0)
		self.len = self.len - len
	else
		self:trim()
	end
end


function Chunk_mt:_tee(...)
	local targets = {...}
	local spawned
	local total = self.len

	if type(targets[#targets]) == "function" then
		local f = table.remove(targets)
		spawned = (function()
			local sender, recver = self.hub:pipe()
			self.hub:spawn(function() f(recver) end)
			return sender
		end)()
	end

	while self.len > 0 do
		local err = self:readin(1)
		if err then break end
		local err = self:_tee_once(spawned, unpack(targets))
		if err then break end
	end

	if spawned then spawned:close() end
	if err then return err end
	return nil, total
end


local R_Tee_mt = {}
R_Tee_mt.__index = R_Tee_mt


function R_Tee_mt:clone()
	local c = setmetatable({}, R_mt)
	c.hub = self.r.hub
	c.no = self.r.no
	c.timeout = self.r.timeout
	local sender, recver = self.r.hub:flag()
	self.evs[sender] = 1
	c.t_ev = recver
	return c
end


local function R_Tee(r)
	local self = setmetatable({}, R_Tee_mt)
	self.r = r
	self.evs = {}
	self.r.hub:spawn(function()
		while true do
			local err, sender, value = self.r.r_ev:recv()
			for ev, v in pairs(self.evs) do
				ev:send(value)
			end
		end
	end)
	return self
end


function Chunk_mt:_tee_0copy(...)
	-- TODO: error handling, test what happens when and an end is interupted part
	-- way through
	-- TODO: if a target blocks on it's w_ev, it'll block forever at the moment
	local targets = {...}
	local spawned
	local last
	local total = self.len

	local buf, len = self:value()
	if self.len - len < MIN_SPLICE_SIZE then
		return self:_tee(...)
	end

	if type(targets[#targets]) == "function" then
		local f = table.remove(targets)
		spawned = (function()
			local sender, recver = self.hub:pipe()
			self.hub:spawn(function() f(recver) end)
			return sender
		end)()
	end

	-- manually flush buffered bytes
	if len > 0 then
		local err = self:_tee_once(spawned, unpack(targets))
		if err then
			if spawned then spawned:close() end
			return err
		end
	end

	-- if the final target isn't a callable, seperate so we can manually splice
	-- to it
	if not spawned then last = table.remove(targets) end

	local r, w = self.hub.io:pipe()
	local r_tee = R_Tee(r)
	local source = self.stream.conn

	-- wire splice r, w pairs' evs together
	w.w_ev.set = function(self, ...)
		source.r_ev:set(...)
	end

	local tees = {}
	local sel = self.hub:selector()

	-- target writers
	for i, target in ipairs(targets) do
		local tee = (function()
			local sender, recver = self.hub:pipe()
			self.hub:spawn(function()
				local r = r_tee:clone()
				local towrite = self.len
				while towrite > 0 do
					local err, n = r:_tee(target, towrite)
					if err then sender:close(); return end
					local err = sender:send(n)
					if err then return end
					towrite = towrite - n
				end
			end)
			return recver
		end)()
		tees[tee] = 0
		tee:redirect(sel)
	end

	-- source reader
	self.hub:spawn(function()
		local toread = self.len
		while toread > 0 do
			local err, n = source:_splice(w, toread)
			if err then w:close(); return end
			toread = toread - n
		end
	end)

	-- coordinator
	local r_last = r_tee:clone()
	local remain = self.len
	local done = 0

	while done < remain do
		local err, tee, n = sel:recv()
		if err then
			if tees[tee] < remain then
				w:close()
				return err
			end

		else
			tees[tee] = tees[tee] + n

			local min = tees[tee]
			for k, v in pairs(tees) do
				min = math.min(min, v)
			end

			if min > done then
				local chunk = Chunk(r_last:stream(), min - done)
				chunk.tee = nil
				chunk.splice = function(self, target)
					assert(self == chunk)
					local total = self.len
					while self.len > 0 do
						local err, n = self.stream.conn:_splice(target, self.len)
						if err then return err end
						self.len = self.len - n
					end
					self.done:close()
					return nil, total
				end

				if spawned then
					spawned:send(chunk)
					chunk.done:recv()
					assert(chunk.len == 0)
				else
					local err = chunk:splice(last)
					if err then return err end
				end

				done = min
			end
		end
	end

	r:close()
	w:close()
	if spawned then spawned:close() end
	return nil, total
end


if _.tee then
	Chunk_mt.tee = Chunk_mt._tee_0copy
else
	Chunk_mt.tee = Chunk_mt._tee
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
	local __
	__, m.w_ev = self.hub:register(no, false, true)
	return m
end


function IO_mt:rw(no, timeout)
	local m = setmetatable({hub = self.hub, no = no, timeout=timeout}, RW_mt)
	m.r_ev, m.w_ev = self.hub:register(no, true, true)
	return m
end


function IO_mt:pipe(timeout)
	local r, w = _.pipe()
	_.fcntl_nonblock(r)
	_.fcntl_nonblock(w)
	return self:r(r, timeout), self:w(w, timeout)
end


function IO_mt:open(name, ...)
	local err, no, mode = _.open(name, ...)
	if err then return err end

	if bit.band(C.O_WRONLY, mode) > 0 then
		local m = setmetatable({hub = self.hub, no = no}, W_mt)
		local __
		__, m.w_ev = self.hub:register_nopoll(no, false, true)
		return nil, m
	end

	if bit.band(C.O_RDWR, mode) > 0 then
		local m = setmetatable({hub = self.hub, no = no}, RW_mt)
		m.r_ev, m.w_ev = self.hub:register_nopoll(no, true, true)
		return nil, m
	end

	local m = setmetatable({hub = self.hub, no = no}, R_mt)
	m.r_ev = self.hub:register_nopoll(no, true)
	return nil, m
end


IO_mt.iovec = d.Iovec
IO_mt.R_mt = R_mt


return function(hub)
	return setmetatable({hub = hub}, IO_mt)
end
