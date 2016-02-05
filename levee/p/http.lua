local ffi = require('ffi')
local C = ffi.C

local errors = require("levee.errors")
local _ = require("levee._")
local d = require("levee.d")
local json = require("levee.p.json")
local meta = require("levee.meta")


local VERSION = "HTTP/1.1"
local FIELD_SEP = ": "
local EOL = "\r\n"

local USER_AGENT = ("%s/%s"):format(meta.name, meta.version.string)


--
-- Status

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
-- Droplet

local Droplet_mt = {}
Droplet_mt.__index = Droplet_mt


function Droplet_mt:route(path, f)
	self.routes[path] = f
end


function Droplet_mt:bundle(path, assets)
	self.bundles[path] = assets
end


local function Droplet(hub, port)
	local self = setmetatable({}, Droplet_mt)

	self.hub = hub
	self.routes = {}
	self.bundles = {}

	local err
	err, self.serve = hub.http:listen(port)
	if err then return err end

	local function request(h, conn, req)
		for path, f in pairs(self.routes) do
			if path == req.path then
				local s = f(h, req)
				if s then
					req.response:send({Status(200), {}, s})
				end
				return
			end
		end

		for path, assets in pairs(self.bundles) do
			if req.path:sub(1, #path) == path then
				local static = assets[req.path:sub(#path)]
				if not static then break end
				req.response:send({Status(200), {}, static})
			end
		end

		req.response:send({Status(404), {}, "Not found."})
	end

	local function connection(h, conn)
		for req in conn do
			request(h, conn, req)
		end
	end

	hub:spawn(function()
		for conn in self.serve do
			hub:spawn(function() connection(hub, conn) end)
		end
	end)

	return nil, self
end


--
-- Parser

local Parser_mt = {}
Parser_mt.__index = Parser_mt


function Parser_mt:__new()
	return ffi.new(self)
end


function Parser_mt:__tostring()
	return string.format(
		"levee.http.Parser: %s", self.response and "response" or "request")
end


function Parser_mt:init_request(config)
	C.sp_http_init_request(self)
	self:config(config)
end


function Parser_mt:init_response(config)
	C.sp_http_init_response(self)
	self:config(config)
end


function Parser_mt:reset()
	C.sp_http_reset(self)
end


function Parser_mt:config(t)
	if type(t) ~= "table" then return end
	if t.max_method then self.max_method = t.max_method end
	if t.max_uri then self.max_uri = t.max_uri end
	if t.max_reason then self.max_reason = t.max_reason end
	if t.max_field then self.max_field = t.max_field end
	if t.max_value then self.max_value = t.max_value end
end


function Parser_mt:next(buf, len)
	local rc = C.sp_http_next(self, buf, len)
	if rc >= 0 then
		return nil, rc
	end
	return errors.get(rc)
end


function Parser_mt:is_done()
	return C.sp_http_is_done(self)
end


function Parser_mt:has_value()
	return
		self.type == C.SP_HTTP_REQUEST or
		self.type == C.SP_HTTP_RESPONSE or
		self.type == C.SP_HTTP_FIELD or
		self.type == C.SP_HTTP_BODY_START or
		self.type == C.SP_HTTP_BODY_CHUNK
end


function Parser_mt:value(buf)
	if self.type == C.SP_HTTP_REQUEST then
		return
			ffi.string(
				buf + self.as.request.method_off, self.as.request.method_len),
			ffi.string(buf + self.as.request.uri_off, self.as.request.uri_len),
			self.as.request.version
	elseif self.type == C.SP_HTTP_RESPONSE then
		return
			self.as.response.status,
			ffi.string(
				buf + self.as.response.reason_off, self.as.response.reason_len),
			self.as.request.version
	elseif self.type == C.SP_HTTP_FIELD then
		return
			ffi.string(buf + self.as.field.name_off, self.as.field.name_len),
			ffi.string(buf + self.as.field.value_off, self.as.field.value_len)
	elseif self.type == C.SP_HTTP_BODY_START then
		return
			false,
			self.as.body_start.chunked,
			self.as.body_start.content_length
	elseif self.type == C.SP_HTTP_BODY_CHUNK then
		return
			true,
			self.as.body_chunk.length
	elseif self.type == C.SP_HTTP_BODY_END then
		return
			false,
			0
	end
end


function Parser_mt:stream_next(stream)
	local err, n = self:next(stream:value())
	if err then return err end

	if n > 0 then
		local value = {self:value(stream:value())}
		stream:trim(n)
		if self:is_done() then
			self:reset()
		end
		return nil, value
	end

	local err, n = stream:readin()
	if err then return err end
	return self:stream_next(stream)
end


local Parser = ffi.metatype("SpHttp", Parser_mt)


local parser = {}

parser.Request = function(config)
	local p = Parser()
	p:init_request(config)
	return p
end


parser.Response = function(config)
	local p = Parser()
	p:init_response(config)
	return p
end


--
-- Date response header cache

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
-- Client

local Client_mt = {}
Client_mt.__index = Client_mt


local Response_mt = {}
Response_mt.__index = Response_mt

function Response_mt:__tostring()
	return ("levee.http.Response: %s %s"):format(self.code, self.reason)
end

function Response_mt:tostring()
	if self.body then
		return self.body:tostring()
	end

	if not self.chunks then return "" end

	local bits = {}
	for chunk in self.chunks do
		local s = chunk:tostring()
		if s == nil then return end
		table.insert(bits, s)
	end
	return table.concat(bits)
end


function Response_mt:tobuffer(buf)
	if self.body then
		return self.body:tobuffer(buf)
	end

	if not self.chunks then return nil, buf end

	local err, buf
	for chunk in self.chunks do
		err, buf = chunk:tobuffer(buf)
		if err then return err end
	end
	return nil, buf
end


function Response_mt:save(name)
	local err, w = self.hub.io:open(name, "w+")
	if err then return err end

	if self.body then
		local err, n = self.body:splice(w)
		w:close()
		return err, n
	end

	local total = 0
	for chunk in self.chunks do
		local err, n = chunk:splice(w)
		if err then w:close(); return err end
		total = total + n
	end
	w:close()
	return nil, n
end


function Response_mt:discard()
	if self.body then
		return self.body:discard()
	end

	if not self.chunks then return end

	local total = 0
	for chunk in self.chunks do
		local err, n = chunk:discard()
		if err then return err end
		total = total + n
	end
	return nil, total
end


function Response_mt:json()
	if self.body then return self.body:json() end

	-- TODO: i think this is something we can generalize
	local ChunkedStream_mt = {}
	ChunkedStream_mt.__index = ChunkedStream_mt

	function ChunkedStream_mt:readin()
		if self.chunk.stream.buf.len < self.chunk.len then
			-- we haven't read in all of this chunk yet
			return self.chunk:readin()
		end
		-- must need the next chunk
		self.chunk.done:close()
		local err
		err, self.chunk = self.chunks:recv()
		if err then return err end
		return self.chunk:readin(1)
	end

	function ChunkedStream_mt:value()
		return self.chunk:value()
	end

	function ChunkedStream_mt:trim(n)
		return self.chunk:trim(n)
	end

	local stream = setmetatable({chunks = self.chunks}, ChunkedStream_mt)
	local err
	err, stream.chunk = self.chunks:recv()
	if err then return err end
	local decoder = json.decoder()
	return decoder:stream(stream)
end


function Client_mt:reader(responses)
	for response in responses do
		local err, value

		err, value = self.parser:stream_next(self.stream)
		if err then goto __cleanup end
		assert(self.parser.type == C.SP_HTTP_RESPONSE)

		local res = setmetatable({
			hub = self.hub,
			client = self,
			code = value[1],
			reason = value[2],
			version = value[3],
			headers = {}, }, Response_mt)

		while true do
			err, value = self.parser:stream_next(self.stream)
			if err then goto __cleanup end
			if not value[1] then break end
			res.headers[value[1]] = value[2]
		end

		if not value[2] then
			-- content-length
			local len = tonumber(value[3])
			if len > 0 then res.body = self.stream:chunk(len) end
			response:send(res)
			if len > 0 then res.body.done:recv() end

		else
			-- chunked tranfer
			local chunks
			chunks, res.chunks = self.hub:pipe()
			response:send(res)

			while true do
				err, value = self.parser:stream_next(self.stream)
				if err then goto __cleanup end
				if not value[1] then break end

				local len = tonumber(value[2])

				if self.stream.buf.sav > 0 then
					len = len + self.stream.buf.sav
					self.stream.buf:thaw()
				end

				local chunk = self.stream:chunk(len)
				chunks:send(chunk)
				-- TODO: still need to package this up better
				chunk.done:recv()
				if chunk.len > 0 then
					chunk:readin(chunk.len)
					self.stream.buf:freeze(chunk.len)
				end
			end
			err, value = self.parser:stream_next(self.stream)
			if err then goto __cleanup end
			-- TODO: trailing headers
			assert(not value[1])
			chunks:close()
		end
	end

	::__cleanup::
	self:close()
end


function Client_mt:__headers(headers)
	-- TODO: Host
	local ret = {
		Host = self.HOST,
		["User-Agent"] = USER_AGENT,
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

	local err = self.conn:send(("%s %s %s\r\n"):format(method, path, VERSION))
	if err then return err end

	headers = self:__headers(headers)
	if data then
		headers["Content-Length"] = tostring(#data)
	end

	for k, v in pairs(headers) do
		local err = self.conn:send(k, FIELD_SEP, v, EOL)
		if err then return err end
	end
	self.conn:send(EOL)

	if data then
		local err = self.conn:send(data)
		if err then return err end
	end

	local sender, recver = self.hub:pipe()
	self.responses:send(sender)
	return nil, recver
end


function Client_mt:get(path, options)
	options = options or {}
	return self:request("GET", path, options.params, options.headers)
end


function Client_mt:head(path, options)
	options = options or {}
	return self:request("HEAD", path, options.params, options.headers)
end


function Client_mt:post(path, options)
	options = options or {}
	return self:request(
		"POST", path, options.params, options.headers, options.data)
end


function Client_mt:close()
	if self.closed then return end
	self.closed = true
	self.conn:close()
	self.responses:close()
end


--
-- Server
--
local Request_mt = {}
Request_mt.__index = Request_mt


function Request_mt:_open(name)
	-- TODO: chroot
	local err, no, st
	err, no = _.open(name, C.O_RDONLY)
	if err then return err end

	local err, st = _.fstat(no)
	if err then goto __cleanup end

	-- check this is a regular file
	if bit.band(st.st_mode, C.S_IFREG) == 0 then
		err = errors.system.EACCES
		goto __cleanup
	end

	if not err then return nil, no, st.st_size end

	::__cleanup::
	_.close(no)
	return err
end


function Request_mt:_sendfile(no, size)

	local off = 0

	while true do
		local n = C.levee_sendfile(self.conn.no, no, off, size - off)

		if n > 0 then
			off = off + n
			if off == size then
				break
			end
		end
		local err, ev = self.conn.w_ev:recv()
		if err then
			return err
		end
	end

	self.response:close()
end


function Request_mt:sendfile(name)
	local err, no, size = self:_open(name)
	if err then
		self.response:send({Status(404), {}, "Not Found\n"})
		return
	end

	self.response:send({Status(200), {}, size})
	local err = self:_sendfile(no, size)
	self.response:close()
	_.close(no)

	if err then self.serve:close() end
	return err
end


function Request_mt:__tostring()
	return ("levee.http.Request: %s %s"):format(self.method, self.path)
end


local Server_mt = {}
Server_mt.__index = Server_mt


function Server_mt:recv()
	return self.requests:recv()
end


function Server_mt:__call()
	local err, value = self.requests:recv()
	if err then return end
	return value
end


function Server_mt:_response(response)
	local err, value = response:recv()
	if err then return err end
	local status, headers, body = unpack(value)
	local no_content = status == Status[304] -- TODO: check if status.code == 304

	local err = self.conn:send(status)
	if err then return err end

	headers["Date"] = httpdate()

	if no_content then
		headers["Content-Length"] = nil
	elseif type(body) == "string" then
		headers["Content-Length"] = tostring(#body)
	elseif body ~= nil then
		headers["Content-Length"] = tostring(tonumber(body))
	else
		headers["Transfer-Encoding"] = "chunked"
	end

	for k, v in pairs(headers) do
		local err = self.conn:send(k, FIELD_SEP, v, EOL)
		if err then return err end
	end
	self.conn:send(EOL)

	if no_content then
		return self.conn:send()
	end
	if type(body) == "string" then
		return self.conn:send(body)
	end

	if body ~= nil then
		-- wait until headers have been sent
		self.conn.empty:recv()
		-- wait until app signals body sent
		local err = response:recv()
		assert(err)
		return
	end

	local err, chunk = response:recv()
	while not err do
		if type(chunk) == "string" then
			self.conn:send(num2hex(#chunk), EOL, chunk, EOL)
			err, chunk = response:recv()

		else
			self.conn:send(num2hex(chunk), EOL)
			-- wait until headers have been sent
			self.conn.empty:recv()
			-- next chunk signals continue
			err, chunk = response:recv()
			self.conn:send(EOL)
		end
	end
	return self.conn:send("0", EOL, EOL)
end


function Server_mt:writer(responses)
	for response in responses do
		local err = self:_response(response)
		response:close()
		if err then
			self:close()
			return
		end
	end
end


function Server_mt:reader(requests, responses)
	while true do
		local err, value

		err, value = self.parser:stream_next(self.stream)
		if err then goto __cleanup end

		local res_sender, res_recver = self.hub:gate()

		local req = setmetatable({
			hub = self.hub,
			serve = self,
			method = value[1],
			path = value[2],
			version = value[3],
			headers = {},
			conn = self.conn,
			response = res_sender, }, Request_mt)

		while true do
			err, value = self.parser:stream_next(self.stream)
			if err then goto __cleanup end
			if not value[1] then break end
			req.headers[value[1]] = value[2]
		end

		if value[2] then error("TODO: chunked") end

		local len = tonumber(value[3])
		if len > 0 then req.body = self.stream:chunk(len) end
		requests:send(req)
		responses:send(res_recver)
		if len > 0 then req.body.done:recv() end
	end

	::__cleanup::
	requests:close()
	responses:close()
	self:close()
end


function Server_mt:close()
	if self.closed then return end
	self.closed = true
	self.conn:close()
	self.requests:close()
end


local function Server(hub, conn, config)
	local self = setmetatable({}, Server_mt)

	self.hub = hub
	self.conn = conn

	self.stream = self.conn:stream()
	self.parser = parser.Request(config)

	local req_sender, req_recver = hub:pipe()
	local res_sender, res_recver = hub:pipe()
	self.requests = req_recver

	hub:spawn(function() self:reader(req_sender, res_sender) end)
	hub:spawn(function() self:writer(res_recver) end)

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


function Listener_mt:__call()
	local err, value = self.recver:recv()
	if err then return end
	return value
end


function Listener_mt:loop()
	for conn in self.serve do
		self.sender:send(Server(self.hub, conn, self.config))
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


function HTTP_mt:connect(port, host, config)
	if type(port) == "table" then
		config = port
		port = nil
		host = nil
	elseif type(host) == "table" then
		config = host
		host = nil
	end

	local m = setmetatable({}, Client_mt)

	host = host or "127.0.0.1"

	local err, conn = self.hub.tcp:connect(port, host)
	if err then return err end

	local err, peer = _.getpeername(conn.no)

	if peer:port() ~= 80 then
		m.HOST = ("%s:%s"):format(host, port)
	else
		m.HOST = host
	end

	m.hub = self.hub
	m.conn = conn

	m.stream = m.conn:stream()
	m.parser = parser.Response(config)

	local res_sender, res_recver = self.hub:pipe()
	self.hub:spawn(function() m:reader(res_recver) end)
	m.responses = res_sender
	return nil, m
end


function HTTP_mt:listen(port, host, config)
	if type(port) == "table" then
		config = port
		port = nil
		host = nil
	elseif type(host) == "table" then
		config = host
		host = nil
	end
	local err, serve = self.hub.tcp:listen(port, host)
	if err then return err end
	local m = setmetatable(
		{hub = self.hub, serve = serve, config = config},
		Listener_mt)
	m.sender, m.recver = self.hub:pipe()
	self.hub:spawn(m.loop, m)
	return nil, m
end


function HTTP_mt:droplet(port)
	return Droplet(self.hub, port)
end


local M_mt = {}
M_mt.__index = M_mt


M_mt.parser = parser


function M_mt.__call(self, hub)
	return setmetatable({hub = hub}, HTTP_mt)
end


return setmetatable({Status = Status}, M_mt)
