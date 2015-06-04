local parsers = require("levee.parsers")
local meta = require("levee.meta")
local iovec = require("levee.iovec")

local time = require("levee.time")
local Status = require("levee.http.status")


local VERSION = "HTTP/1.1"
local FIELD_SEP = ": "
local EOL = "\r\n"


local function __recv(self)
	return self.recver:recv()
end


--
-- Parser
--
local function __parser(hub, conn, parser, recver)
	for buf in conn do
		if not buf then recver:close() return end

		while true do
			local n = parser:next(buf:value())

			if n < 0 then error("parse error") end

			if n == 0 then break end

			if n > 0 then
				recver:send({parser:value(buf:value())})
				buf:trim(n)
				if parser:is_done() then parser:reset() end
			end
		end
	end
end


local function Parser(hub, conn, parser)
	local recver = hub:pipe()
	hub:spawn(function() __parser(hub, conn, parser, recver) end)
	return recver
end


--
-- Server
--
local Server_mt = {}
Server_mt.__index = Server_mt

Server_mt.__call = __recv
Server_mt.recv = __recv


function Server_mt:write(status, headers, body)
	local hdr = {
		["Date"] = time.httpdate(),
		["Content-Type"] = "text/plain",
		["Some-Value"] = "with stuff",
		["Content-Length"] = "12",
	}

	self.iov:write(Status[200])
	for k,v in pairs(hdr) do
		self.iov:write(k)
		self.iov:write(FIELD_SEP)
		self.iov:write(v)
		self.iov:write(EOL)
	end
	self.iov:write(EOL)
	self.iov:write(body)

	self.conn:send(self.iov)
	self.iov:reset()
end


function Server_mt:loop()
	local _next, req

	while true do
		_next = self.parser:recv()
		if not _next then return end

		req = {headers={}, method=_next[1], path=_next[2], version=_next[3]}
		req.serve = self
		function req:reply(status, headers, body)
			self.serve:write(status, headers, body)
		end

		while true do
			_next = self.parser:recv()
			if not _next then return end
			if not _next[1] then break end
			req.headers[_next[1]] = _next[2]
		end

		self.recver:send(req)
	end
end


local function Server(hub, conn)
	local self = setmetatable({}, Server_mt)
	self.hub = hub
	self.conn = conn
	self.recver = hub:pipe()
	self.parser = Parser(hub, conn, parsers.http.Request())
	self.iov = iovec.Iovec(32)
	hub:spawn(self.loop, self)
	return self
end


--
-- Listener
--
local Listener_mt = {}
Listener_mt.__index = Listener_mt

Listener_mt.__call = __recv
Listener_mt.recv = __recv


function Listener_mt:loop()
	for conn in self.serve do
		self.recver:send(Server(self.hub, conn))
	end
end


--
-- HTTP module interface
--
local HTTP_mt = {}
HTTP_mt.__index = HTTP_mt


function HTTP_mt:connect(port, host)
	local conn = self.hub.tcp:listen(port, host)
	local m = setmetatable({hub = self.hub, conn = conn}, Client_mt)
	m.recver = self.hub:pipe()
	self.hub:spawn(m.loop, m)
	return m
end


function HTTP_mt:listen(port, host)
	local serve = self.hub.tcp:listen(port, host)
	local m = setmetatable({hub = self.hub, serve = serve}, Listener_mt)
	m.recver = self.hub:pipe()
	self.hub:spawn(m.loop, m)
	return m
end


return function(hub)
	return setmetatable({hub = hub}, HTTP_mt)
end
