local ffi = require('ffi')
local C = ffi.C

local parsers = require("levee.parsers")
local meta = require("levee.meta")
local iovec = require("levee.iovec")


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
				if parser.type == C.HTTP_PARSER_BODY_START then
					buf:trim(n)
					local len = parser.as.body_start.content_length
					recver:send({false, ffi.string(buf:value(), len)})
					buf:trim(len)
				else
					recver:send({parser:value(buf:value())})
					buf:trim(n)
				end
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
-- Client
--
local Client_mt = {}
Client_mt.__index = Client_mt


function Client_mt:reader()
	local _next, res

	for response in self.responses do
		_next = self.parser:recv()
		if not _next then return end

		res = {code=_next[1], reason=_next[2], version=_next[3], headers={}}

		while true do
			_next = self.parser:recv()
			if not _next then return end
			if not _next[1] then break end
			res.headers[_next[1]] = _next[2]
		end

		res.body = _next[2]

		response:send(res)
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
	local recver = self.hub:pipe()
	self.responses:send(recver)

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
	self.serve:write(status, headers, body)
end


local Server_mt = {}
Server_mt.__index = Server_mt

Server_mt.__call = __recv
Server_mt.recv = __recv


function Server_mt:write(status, headers, body)
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

	self.iov:write("Content-Length")
	self.iov:write(FIELD_SEP)
	self.iov:write(tostring(#body))
	self.iov:write(EOL)

	self.iov:write(EOL)

	self.iov:write(body)

	self.conn:writev(self.iov.iov, self.iov.n)
	self.iov:reset()
end


function Server_mt:loop()
	local _next, req

	while true do
		_next = self.parser:recv()
		if not _next then return end

		req = setmetatable({
			serve=self,
			method=_next[1],
			path=_next[2],
			version=_next[3],
			headers={}, }, ServerRequest_mt)

		while true do
			_next = self.parser:recv()
			if not _next then return end
			if not _next[1] then break end
			req.headers[_next[1]] = _next[2]
		end

		self.recver:send(req)
	end
end


function Server_mt:close()
	self.conn:close()
	self.recver:close()
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
	m.parser = Parser(self.hub, m.conn, parsers.http.Response())
	m.iov = iovec.Iovec(32)

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
