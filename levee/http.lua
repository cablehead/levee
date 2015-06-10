local ffi = require('ffi')
local C = ffi.C

local parsers = require("levee.parsers")
local meta = require("levee.meta")
local iovec = require("levee.iovec")
local buffer = require("levee.buffer")


local VERSION = "HTTP/1.1"
local FIELD_SEP = ": "
local EOL = "\r\n"


--
-- Statuses
--
local Status = {}

function Status:__call(code, reason)
	if reason then
		return string.format("HTTP/1.1 %d %s\r\n", code, reason)
	end
	return Status[200]
end

setmetatable(Status, Status)

Status[100] = Status(100, "Continue")
Status[101] = Status(101, "Switching Protocols")
Status[102] = Status(102, "Processing")
Status[200] = Status(200, "OK")
Status[201] = Status(201, "Created")
Status[202] = Status(202, "Accepted")
Status[203] = Status(203, "Non-Authoritative Information")
Status[204] = Status(204, "No Content")
Status[205] = Status(205, "Reset Content")
Status[206] = Status(206, "Partial Content")
Status[207] = Status(207, "Multi-Status")
Status[208] = Status(208, "Already Reported")
Status[226] = Status(226, "IM Used")
Status[300] = Status(300, "Multiple Choices")
Status[301] = Status(301, "Moved Permanently")
Status[302] = Status(302, "Found")
Status[303] = Status(303, "See Other")
Status[304] = Status(304, "Not Modified")
Status[305] = Status(305, "Use Proxy")
Status[306] = Status(306, "Switch Proxy")
Status[307] = Status(307, "Temporary Redirect")
Status[308] = Status(308, "Permanent Redirect")
Status[400] = Status(400, "Bad Request")
Status[401] = Status(401, "Unauthorized")
Status[402] = Status(402, "Payment Required")
Status[403] = Status(403, "Forbidden")
Status[404] = Status(404, "Not Found")
Status[405] = Status(405, "Method Not Allowed")
Status[406] = Status(406, "Not Acceptable")
Status[407] = Status(407, "Proxy Authentication Required")
Status[408] = Status(408, "Request Timeout")
Status[409] = Status(409, "Conflict")
Status[410] = Status(410, "Gone")
Status[411] = Status(411, "Length Required")
Status[412] = Status(412, "Precondition Failed")
Status[413] = Status(413, "Request Entity Too Large")
Status[414] = Status(414, "Request-URI Too Long")
Status[415] = Status(415, "Unsupported Media Type")
Status[416] = Status(416, "Requested Range Not Satisfiable")
Status[417] = Status(417, "Expectation Failed")
Status[418] = Status(418, "I'm a teapot")
Status[419] = Status(419, "Authentication Timeout")
Status[420] = Status(420, "Enhance Your Calm")
Status[421] = Status(421, "Misdirected Request")
Status[422] = Status(422, "Unprocessable Entity")
Status[423] = Status(423, "Locked")
Status[424] = Status(424, "Failed Dependency")
Status[426] = Status(426, "Upgrade Required")
Status[428] = Status(428, "Precondition Required")
Status[429] = Status(429, "Too Many Requests")
Status[431] = Status(431, "Request Header Fields Too Large")
Status[440] = Status(440, "Login Timeout")
Status[444] = Status(444, "No Response")
Status[449] = Status(449, "Retry With")
Status[450] = Status(450, "Blocked by Windows Parental Controls")
Status[451] = Status(451, "Unavailable For Legal Reasons")
Status[494] = Status(494, "Request Header Too Large")
Status[495] = Status(495, "Cert Error")
Status[496] = Status(496, "No Cert")
Status[497] = Status(497, "HTTP to HTTPS")
Status[498] = Status(498, "Token expired/invalid")
Status[499] = Status(499, "Client Closed Request")
Status[500] = Status(500, "Internal Server Error")
Status[501] = Status(501, "Not Implemented")
Status[502] = Status(502, "Bad Gateway")
Status[503] = Status(503, "Service Unavailable")
Status[504] = Status(504, "Gateway Timeout")
Status[505] = Status(505, "HTTP Version Not Supported")
Status[506] = Status(506, "Variant Also Negotiates")
Status[507] = Status(507, "Insufficient Storage")
Status[508] = Status(508, "Loop Detected")
Status[509] = Status(509, "Bandwidth Limit Exceeded")
Status[510] = Status(510, "Not Extended")
Status[511] = Status(511, "Network Authentication Required")
Status[520] = Status(520, "Origin Error")
Status[521] = Status(521, "Web server is down")
Status[522] = Status(522, "Connection timed out")
Status[523] = Status(523, "Proxy Declined Request")
Status[524] = Status(524, "A timeout occurred")
Status[598] = Status(598, "Network read timeout error")
Status[599] = Status(599, "Network connect timeout error")

--
-- Date response header cache
--
local http_time = ffi.new("time_t [1]")
local http_date = nil
local http_date_buf = ffi.new("char [32]")
local http_tm = ffi.new("struct tm")

local function httpdate()
	local t = C.time(nil)
	if t ~= http_time[0] then
		http_time[0] = t
		C.gmtime_r(http_time, http_tm)
		local len = C.strftime(
			http_date_buf, 32, "%a, %d %b %Y %H:%M:%S GMT", http_tm)
		http_date = ffi.string(http_date_buf, len)
	end
	return http_date
end


--- Returns HEX representation of num
local hexstr = '0123456789abcdef'
function num2hex(num)
	local s = ''
	while num > 0 do
		local mod = math.fmod(num, 16)
		s = string.sub(hexstr, mod+1, mod+1) .. s
		num = math.floor(num / 16)
	end
	if s == '' then s = '0' end
	return s
end


--
-- Parser
--
local function parser_next(self)
	local n = self.parser:next(self.buf:value())

	if n < 0 then error(("parse error: %s"):format(self.parser)) end

	if n > 0 then
		local value = {self.parser:value(self.buf:value())}
		self.buf:trim(n)
		if self.parser:is_done() then self.parser:reset() end
		return value
	end

	local n, err = self.conn:readinto(self.buf)
	if n <= 0 then return end

	return parser_next(self)
end


--
-- Client
--
local Client_mt = {}
Client_mt.__index = Client_mt


function Client_mt:reader()
	local _next, res

	for response in self.responses do
		_next = parser_next(self)
		if not _next then return end

		res = {
			client = self,
			code = _next[1],
			reason = _next[2],
			version = _next[3],
			headers = {},
			}

		while true do
			_next = parser_next(self)
			if not _next then return end
			if not _next[1] then break end
			res.headers[_next[1]] = _next[2]
		end

		if _next[2] then
			error("chunked")
		end

		res.len = _next[3]
		response:send(res)
		self.baton:wait()

		--[[
		-- chunked tranfer?
		if _next[2] then
			while true do
				_next = parser_next(self.hub, self.conn, self.parser)
				if not _next then return end
				if not _next[1] then break end
				local len = _next[2]
				while len > 0 do
					if self.conn.buf.len == 0 then
						if not self.conn:recv() then return end
					end

					local b, s_len = self.conn.buf:slice(len)
					res.body:send(ffi.string(b, s_len))
					self.conn.buf:trim(s_len)
					len = len - s_len
				end
			end
		else

			local len = _next[3]
			while len > 0 do
				if self.conn.buf.len == 0 then
					if not self.conn:recv() then return end
				end
				local b, s_len = self.conn.buf:slice(len)
				res.body:send(ffi.string(b, s_len))
				self.conn.buf:trim(s_len)
				len = len - s_len
			end
		end
		--]]

	end
end


function Client_mt:__headers(headers)
	-- TODO: Host
	local ret = {
		["User-Agent"] = "levee/" .. meta.version,
		Accept = "*/*", }
	for key, value in pairs(headers or {}) do
		ret[key] = value
	end
	return ret
end


function Client_mt:request(method, path, params, headers, data)
	self.iov:write(("%s %s %s\r\n"):format(method, path, VERSION))

	headers = self:__headers(headers)
	if data then
		headers["Content-Length"] = tostring(#data)
	end

	for k, v in pairs(headers) do
		self.iov:write(k)
		self.iov:write(FIELD_SEP)
		self.iov:write(v)
		self.iov:write(EOL)
	end
	self.iov:write(EOL)

	if data then self.iov:write(data) end

	self.conn:writev(self.iov.iov, self.iov.n)
	self.iov:reset()

	local recver = self.hub:pipe()
	self.responses:send(recver)
	return recver
end


function Client_mt:get(path, options)
	options = options or {}
	return self:request("GET", path, options.params, options.headers)
end


function Client_mt:post(path, options)
	options = options or {}
	return self:request(
		"POST", path, options.params, options.headers, options.data)
end


function Client_mt:close()
	self.conn:close()
	self.responses:close()
end


--
-- Server
--
local ServerRequest_mt = {}
ServerRequest_mt.__index = ServerRequest_mt


function ServerRequest_mt:reply(status, headers, body)
	self.serve.responses:send({status, headers, body})
end


local Server_mt = {}
Server_mt.__index = Server_mt


function Server_mt:recv()
	return self.requests:recv()
end


Server_mt.__call = Server_mt.recv


function Server_mt:writer()
	for response in self.responses do
		local status, headers, body = unpack(response:recv())
		self.iov:write(status)

		self.iov:write("Date")
		self.iov:write(FIELD_SEP)
		self.iov:write(httpdate())
		self.iov:write(EOL)

		for k, v in pairs(headers) do
			self.iov:write(k)
			self.iov:write(FIELD_SEP)
			self.iov:write(v)
			self.iov:write(EOL)
		end

		if type(body) == "string" then
			self.iov:write("Content-Length")
			self.iov:write(FIELD_SEP)
			self.iov:write(tostring(#body))
			self.iov:write(EOL)
			self.iov:write(EOL)
			self.iov:write(body)
			if self.conn:writev(self.iov.iov, self.iov.n) < 0 then
				self:close()
				return
			end
			self.iov:reset()

		else
				error("yarg")
				if type(body) ~= "table" then
					self.iov:write("Content-Length")
					self.iov:write(FIELD_SEP)
					self.iov:write(tostring(#body))
					self.iov:write(EOL)
					self.iov:write(EOL)
					self.iov:write(body)
					if self.conn:writev(self.iov.iov, self.iov.n) < 0 then
						self:close()
						return
					end
					self.iov:reset()

				else
					self.iov:write("Transfer-Encoding")
					self.iov:write(FIELD_SEP)
					self.iov:write("chunked")
					self.iov:write(EOL)
					self.iov:write(EOL)
					if self.conn:writev(self.iov.iov, self.iov.n) < 0 then
						self:close()
						return
					end
					self.iov:reset()

					for s in body do
						self.iov:write(num2hex(#s))
						self.iov:write(EOL)
						self.iov:write(s)
						self.iov:write(EOL)
						if self.conn:writev(self.iov.iov, self.iov.n) < 0 then
							self:close()
							return
						end
						self.iov:reset()
					end

					self.iov:write("0")
					self.iov:write(EOL)
					self.iov:write(EOL)
					if self.conn:writev(self.iov.iov, self.iov.n) < 0 then
						self:close()
						return
					end
					self.iov:reset()
				end
		end
	end
end


function Server_mt:reader()
	local _next, req

	while true do
		_next = parser_next(self)
		if not _next then return end

		req = {
			serve = self,
			method=_next[1],
			path=_next[2],
			version=_next[3],
			headers={},
			response = self.hub:pipe(), }

		while true do
			_next = parser_next(self)
			if not _next then return end
			if not _next[1] then break end
			req.headers[_next[1]] = _next[2]
		end

		if _next[2] then error("TODO: chunked") end

		req.len = _next[3]
		self.requests:send(req)
		self.responses:send(req.response)
		self.baton:wait()
	end
end


function Server_mt:close()
	self.conn:close()
	self.requests:close()
	self.responses:close()
end


local function Server(hub, conn)
	local self = setmetatable({}, Server_mt)
	self.hub = hub
	self.conn = conn
	self.requests = hub:pipe()
	self.responses = hub:pipe()
	self.parser = parsers.http.Request()
	self.buf = buffer(4096)
	self.iov = iovec.Iovec(32)
	self.baton = hub:baton()
	hub:spawn(self.reader, self)
	hub:spawn(self.writer, self)
	return self
end


--
-- Listener
--
local Listener_mt = {}
Listener_mt.__index = Listener_mt


function Listener_mt:recv()
	return self.recver:recv()
end


Listener_mt.__call = Listener_mt.recv


function Listener_mt:loop()
	for conn in self.serve do
		self.recver:send(Server(self.hub, conn))
	end
end


function Listener_mt:close()
	self.serve:close()
	self.recver:close()
end


--
-- HTTP module interface
--
local HTTP_mt = {}
HTTP_mt.__index = HTTP_mt


function HTTP_mt:connect(port, host)
	local m = setmetatable({}, Client_mt)

	m.hub = self.hub
	m.conn = self.hub.tcp:connect(port, host)
	m.parser = parsers.http.Response()
	m.buf = buffer(4096)
	m.iov = iovec.Iovec(32)
	m.baton = self.hub:baton()

	m.responses = self.hub:pipe()
	self.hub:spawn(m.reader, m)
	return m
end


function HTTP_mt:listen(port, host)
	local serve = self.hub.tcp:listen(port, host)
	local m = setmetatable({hub = self.hub, serve = serve}, Listener_mt)
	m.recver = self.hub:pipe()
	self.hub:spawn(m.loop, m)
	return m
end


return {
	Status = Status,
	__plugin = function(hub)
		return setmetatable({hub = hub}, HTTP_mt)
	end, }