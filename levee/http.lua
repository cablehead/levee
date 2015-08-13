local ffi = require('ffi')
local C = ffi.C

local parsers = require("levee.parsers")
local meta = require("levee.meta")
local iovec = require("levee.iovec")
local buffer = require("levee.buffer")
local json = require("levee.json")
local sys = require("levee.sys")


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
	return Status[code]
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
-- Stream
--
local Stream_mt = {}
Stream_mt.__index = Stream_mt

function Stream_mt:__tostring()
	return ("levee.http.Stream: len=%s buffered=%s"):format(
		tonumber(self.len), #self.buf)
end

function Stream_mt:__len()
	return self.len
end

function Stream_mt:readin()
	return self.conn:readinto(self.buf)
end

function Stream_mt:value()
	return self.buf:slice(self.len)
end

function Stream_mt:trim(len)
	if len then
		assert(len <= self.len)
	else
		len = self.len
	end
	local got = self.buf:trim(len)
	self.len = self.len - got
	if self.len == 0 then
		self.done:close()
	end
end

function Stream_mt:splice(conn)
	while true do
		local n, err = conn:write(self:value())
		self:trim()
		if self.len == 0 then break end
		self:readin()
	end
end

function Stream_mt:tostring()
	local ret = {}
	while true do
		local seg = self.buf:take_s(self.len)
		table.insert(ret, seg)
		self.len = self.len - #seg
		if self.len == 0 then
			break
		end
		self:readin()
	end
	self.done:close()
	return table.concat(ret)
end

function Stream_mt:discard()
	while true do
		local seg = self.buf:take_s(self.len)
		self.len = self.len - #seg
		if self.len == 0 then
			break
		end
		self:readin()
	end
	self.done:close()
end

function Stream_mt:json()
	local parser = json.decoder()
	local ok, got = parser:stream_consume(self)
	-- TODO: ensure not more than len is consumed
	self.len = 0
	self.done:close()
	return ok, got
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


local Response_mt = {}
Response_mt.__index = Response_mt

function Response_mt:__tostring()
	return ("levee.http.Response: %s %s"):format(self.code, self.reason)
end

function Response_mt:consume()
	if self.body then
		return self.body:tostring()
	end

	local bits = {}
	for chunk in self.chunks do
		table.insert(bits, chunk:tostring())
	end
	return table.concat(bits)
end

function Response_mt:save(name)
	local function _save(chunk, no)
		while #chunk > 0 do
			local buf, len = chunk:value()
			if len == 0 then
				chunk:readin()
			else
				local n = C.write(no, buf, len)
				chunk:trim(n)
			end
		end
	end

	local no = C.open(name, C.O_WRONLY)
	if no < 0 then return no, ffi.errno() end

	if self.body then
		_save(self.body, no)
	else
		for chunk in self.chunks do
			_save(chunk, no)
		end
	end

	C.close(no)
	return 0
end

function Response_mt:discard()
	if self.body then
		self.body:discard()
		return true
	end

	for chunk in self.chunks do
		chunk:discard()
	end
	return true
end

function Response_mt:json()
	if self.body then
		local ok, data = self.body:json()
		if not ok then
			-- TODO: is this reasonable?
			return nil, data
		end
		return data
	end

	local ChunkedStream_mt = {}
	ChunkedStream_mt.__index = ChunkedStream_mt

	function ChunkedStream_mt:readin()
		if self.chunk.buf.len < self.chunk.len then
			-- we haven't read in all of this chunk yet
			return self.chunk:readin()
		end
		-- must need the next chunk
		self.chunk.done:close()
		self.chunk = self.chunks:recv()
		return self.chunk.len
	end

	function ChunkedStream_mt:value()
		return self.chunk:value()
	end

	function ChunkedStream_mt:trim(n)
		return self.chunk:trim(n)
	end

	local stream = setmetatable(
		{chunks = self.chunks, chunk = self.chunks:recv()}, ChunkedStream_mt)

	local parser = json.decoder()
	local ok, data = parser:stream_consume(stream)
	if not ok then
		-- TODO: is this reasonable?
		return nil, data
	end
	return data
end

function Client_mt:reader()
	local _next, res

	for response in self.responses do
		_next = parser_next(self)
		if not _next then return end

		res = setmetatable({
			client = self,
			code = _next[1],
			reason = _next[2],
			version = _next[3],
			headers = {},
			}, Response_mt)

		while true do
			_next = parser_next(self)
			if not _next then return end
			if not _next[1] then break end
			res.headers[_next[1]] = _next[2]
		end

		-- content-length
		if not _next[2] then
			-- TODO: handle Content-Length == 0

			res.body = setmetatable({
				len = tonumber(_next[3]),
				conn = self.conn,
				buf = self.buf,
				-- TODO: done should be an ultra lightweight primitive
				done = self.hub:pipe(), }, Stream_mt)

			response:send(res)
			res.body.done:recv()

		-- chunked tranfer
		else
			res.chunks = self.hub:pipe()
			response:send(res)

			while true do
				_next = parser_next(self)
				if not _next then return end
				if not _next[1] then break end

				local len = tonumber(_next[2])

				if self.buf.sav > 0 then
					len = len + self.buf.sav
					self.buf:thaw()
				end

				local chunk = setmetatable({
					len = len,
					conn = self.conn,
					buf = self.buf,
					done = self.hub:pipe(), }, Stream_mt)

				res.chunks:send(chunk)
				-- TODO: still need to package this up better
				chunk.done:recv()
				if chunk.len > 0 then
					while #chunk.buf < chunk.len do chunk:readin() end
					self.buf:freeze(chunk.len)
				end
			end

			res.chunks:close()
		end
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
	-- TODO: url encode params
	if params then
		local s = {path, "?"}
		for key, value in pairs(params) do
			table.insert(s, key)
			table.insert(s, "=")
			table.insert(s, value)
			table.insert(s, "&")
		end
		table.remove(s)
		path = table.concat(s)
	end

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
local Request_mt = {}
Request_mt.__index = Request_mt

function Request_mt:_sendfile(name)
	local no = C.open(name, C.O_RDONLY)
	if no < 0 then return false, -1 end

	local st = sys.os.fstat(no)
	if not st then return false, no end
	-- check this is a regular file
	if bit.band(st.st_mode, C.S_IFREG) == 0 then return false, no end

	self.response:send({Status(200), {}, st.st_size})

	local off = 0

	while true do
		local n = C.levee_sendfile(self.conn.no, no, off, st.st_size - off)

		if n > 0 then
			off = off + n
			if off == st.st_size then
				break
			end
		end

		local ev = self.conn.w_ev:recv()
		assert(ev > 0)  -- TODO: handle shutdown on error
	end

	self.response:close()
	return true, no
end

function Request_mt:sendfile(name)
	local ok, no = self:_sendfile(name)
	if not ok then
		self.response:send({Status(404), {}, "Not Found\n"})
	end
	if no > 0 then
		C.close(no)
	end
end

function Request_mt:__tostring()
	return ("levee.http.Request: %s %s"):format(self.method, self.path)
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

		elseif body ~= nil then
			self.iov:write("Content-Length")
			self.iov:write(FIELD_SEP)
			self.iov:write(tostring(tonumber(body)))
			self.iov:write(EOL)
			self.iov:write(EOL)
			if self.conn:writev(self.iov.iov, self.iov.n) < 0 then
				self:close()
				return
			end
			self.iov:reset()

			assert(not response:recv())

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

				local function write_chunk(response, chunk)
					if type(chunk) == "string" then
						self.iov:write(num2hex(#chunk))
						self.iov:write(EOL)
						self.iov:write(chunk)
						self.iov:write(EOL)
						if self.conn:writev(self.iov.iov, self.iov.n) < 0 then
							return
						end
						self.iov:reset()

						chunk = response:recv()

					else
						self.iov:write(num2hex(chunk))
						self.iov:write(EOL)
						if self.conn:writev(self.iov.iov, self.iov.n) < 0 then
							return
						end
						self.iov:reset()

						chunk = response:recv()

						self.iov:write(EOL)
						if self.conn:writev(self.iov.iov, self.iov.n) < 0 then
							return
						end
						self.iov:reset()
					end

					if not chunk then return true end
					return write_chunk(response, chunk)
				end

				local ok = write_chunk(response, response:recv())
				if not ok then
					self:close()
					return
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


function Server_mt:reader()
	local _next, req

	while true do
		_next = parser_next(self)
		if not _next then
			self:close()
			return
		end

		req = setmetatable({
			serve = self,
			method=_next[1],
			path=_next[2],
			version=_next[3],
			headers={},
			conn = self.conn,
			response = self.hub:pipe(), }, Request_mt)

		while true do
			_next = parser_next(self)
			if not _next then
				self:close()
				return
			end
			if not _next[1] then break end
			req.headers[_next[1]] = _next[2]
		end

		if _next[2] then error("TODO: chunked") end

		local len = _next[3]

		if len > 0 then
			req.body = setmetatable({
				len = len,
				conn = self.conn,
				buf = self.buf,
				done = self.hub:pipe(), }, Stream_mt)
		end

		self.requests:send(req)
		self.responses:send(req.response)

		if len > 0 then req.body.done:recv() end
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
	self.buf = buffer(64*1024)
	self.iov = iovec.Iovec(32)
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


function Listener_mt:addr()
	return self.serve:addr()
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

	local conn, err = self.hub.tcp:connect(port, host)
	if not conn then
		return conn, err
	end

	m.hub = self.hub
	m.conn = conn
	m.parser = parsers.http.Response()
	m.buf = buffer(64*1024)
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


local M_mt = {}
M_mt.__index = M_mt


function M_mt.__call(self, hub)
	return setmetatable({hub = hub}, HTTP_mt)
end


return setmetatable({Status = Status}, M_mt)
