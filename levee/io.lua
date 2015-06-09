local ffi = require("ffi")
local C = ffi.C

local sys = require("levee.sys")
local errno = require("levee.errno")


--
-- Read
--
local R_mt = {}
R_mt.__index = R_mt


function R_mt:read(buf, len)
	if self.closed then return -1, errno["EBADF"] end

	local ev = self.r_ev:recv()

	local n, err = sys.os.read(self.no, buf, len)

	if n == 0 then
		self:close()
		return n, err
	end

	-- TODO:
	-- if n == len, maybe don't wait on r_ev on next read
	-- if ev == -1 and n != len, maybe close and set err
	if n > 0 then
		return n
	end

	if err ~= errno["EAGAIN"] then
		self:close()
		return n, err
	end

	-- EAGAIN
	return self:read(buf, len)
end


function R_mt:close()
	self.closed = true
	self.hub:unregister(self.no, true)
end


--
-- Write
--
local W_mt = {}
W_mt.__index = W_mt


function W_mt:write(buf, len)
	if self.closed then return -1, errno["EBADF"] end

	local n, err = sys.os.write(self.no, buf, len)

	if n < 0 then
		self:close()
		return n, err
	end

	return n, err
end


function W_mt:writev(iov, n)
	-- TODO: close on error, return errno
	return C.writev(self.no, iov, n)
end


function W_mt:close()
	self.closed = true
	self.hub:unregister(self.no, false, true)
end


--
-- Read / Write
--
local RW_mt = {}
RW_mt.__index = RW_mt

RW_mt.read = R_mt.read
RW_mt.write = W_mt.write
RW_mt.writev = W_mt.writev


function RW_mt:close()
	self.closed = true
	self.hub:unregister(self.no, true, true)
end


--
-- IO module interface
--
local IO_mt = {}
IO_mt.__index = IO_mt


function IO_mt:r(no)
	local m = setmetatable({hub = self.hub, no = no}, R_mt)
	m.r_ev = self.hub:register(no, true)
	return m
end


function IO_mt:w(no)
	local m = setmetatable({hub = self.hub, no = no}, W_mt)
	local _
	_, m.w_ev = self.hub:register(no, false, true)
	return m
end


function IO_mt:rw(no)
	local m = setmetatable({hub = self.hub, no = no}, RW_mt)
	m.r_ev, m.w_ev = self.hub:register(no, true, true)
	return m
end


function IO_mt:pipe()
	local r, w = sys.os.pipe()
	sys.os.nonblock(r)
	sys.os.nonblock(w)
	return self:r(r), self:w(w)
end


return function(hub)
	return setmetatable({hub = hub}, IO_mt)
end
