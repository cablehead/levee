local ffi = require('ffi')
local C = ffi.C

local errors = require("levee.errors")
local _ = require("levee._")
local json = require("levee.p.json")
local meta = require("levee.meta")
local Map = require("levee.d.map")
local Parser = require("levee.p.http.parse")
local Status = require("levee.p.http.status")


local VERSION = "HTTP/1.1"
local FIELD_SEP = ": "
local EOL = "\r\n"

local USER_AGENT = ("%s/%s"):format(meta.name, meta.version.string)


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


local function Droplet(hub, port, host, config)
	local self = setmetatable({}, Droplet_mt)

	self.hub = hub
	self.routes = {}
	self.bundles = {}

	local err
	err, self.serve = hub.http:listen(port, host, config)
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


---
--- parser

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


function send_headers(conn, headers)
	for k, v in pairs(headers) do
		if type(v) == "table" then
			for _,item in pairs(v) do
				local err = conn:send(k, FIELD_SEP, item, EOL)
				if err then return err end
			end
		else
			local err = conn:send(k, FIELD_SEP, v, EOL)
			if err then return err end
		end
	end
	return conn:send(EOL)
end


function recv_headers(parser, stream)
	local headers = {}, err, value
	while true do
		err, value = parser:stream_next(stream)
		if err then return err end
		local key = value[1]
		if not key then break end
		local current = headers[key]
		if type(current) == "string" then
			 headers[key] = {current,value[2]}
		elseif type(current) == "table" then
			table.insert(headers[key], value[2])
		else
			headers[key] = value[2]
		end
	end

	local len
	if not value[2] then len = tonumber(value[3]) end
	return nil, headers, len
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
	local inprogress
	for response in responses do
		inprogress = response
		local request = self.response_to_request[response]
		self.response_to_request[response] = nil

		local err, value, len
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

		err, res.headers, len = recv_headers(self.parser, self.stream)
		if err then goto __cleanup end

		-- handle body
		if request.method == "HEAD" then
			response:send(res)
			self.parser:reset()

		else
			if len then
				-- content-length
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
		inprogress = nil
	end

	::__cleanup::
	if inprogress then inprogress:close() end
	for response in responses do responses:close() end
	self:close()
end


function Client_mt:_headers(headers)
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

	headers = self:_headers(headers)
	if data then
		headers["Content-Length"] = tostring(#data)
	end

	local err = send_headers(self.conn, headers)
	if err then return err end

	if data then
		local err = self.conn:send(data)
		if err then return err end
	end

	local sender, recver = self.hub:pipe()
	local request = {method=method}
	self.response_to_request[sender] = request
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


function Request_mt:sendfile(name)
	local err, r = self.hub.io:open(name)
	if err then
		self.response:send({Status(404), {}, "Not Found\n"})
		return
	end

	local err, st = r:stat()
	if err or not st:is_reg() then
		r:close()
		self.response:send({Status(404), {}, "Not Found\n"})
		return err or errors.system.EACCES
	end

	self.response:send({Status(200), {}, st.st_size})
	err, n = r:sendfile(self.conn, st.st_size)
	self.response:close()
	r:close()

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


function Server_mt:_response(request, response)
	local err, value = response:recv()
	if err then return err end
	local status, headers, body = unpack(value)
	local no_content = status:no_content()

	local err = self.conn:send(tostring(status))
	if err then return err end

	if not headers["Date"] then
		headers["Date"] = httpdate()
	end

	if no_content then
		headers["Content-Length"] = nil
	elseif type(body) == "string" then
		headers["Content-Length"] = tostring(#body)
	elseif body ~= nil then
		headers["Content-Length"] = tostring(tonumber(body))
	else
		headers["Transfer-Encoding"] = "chunked"
	end

	local err = send_headers(self.conn, headers)
	if err then return err end

	if no_content or request.method == "HEAD" then
		return
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


function Server_mt:writer(responses, response_to_request)
	for response in responses do
		local request = response_to_request[response]
		response_to_request[response] = nil
		local err = self:_response(request, response)
		response:close()
		self.parser:reset()
		if err then
			self:close()
			return
		end
	end
end


function Server_mt:reader(requests, responses, response_to_request)
	while true do
		local err, value, len

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

		err, req.headers, len = recv_headers(self.parser, self.stream)
		if err then goto __cleanup end

		if not len then error("TODO: chunked") end

		if len > 0 then req.body = self.stream:chunk(len) end
		response_to_request[res_recver] = req
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

	local response_to_request = {}
	hub:spawn(function() self:reader(req_sender, res_sender, response_to_request) end)
	hub:spawn(function() self:writer(res_recver, response_to_request) end)

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


local function Options(port, host, options)
	if type(port) == "table" then
		return port
	elseif type(host) == "table" then
		return host
	end

	local o = {port = port, host = host}
	for k, v in pairs(options) do
		o[k] = v
	end
	return o
end

--
-- HTTP module interface
--
local HTTP_mt = {}
HTTP_mt.__index = HTTP_mt


function HTTP_mt:connect(port, host, options)
	options = options or {}

	local m = setmetatable({}, Client_mt)

	host = host or "127.0.0.1"

	options = Options(port, host, options)

	local err, conn = self.hub.tcp:connect(options)
	if err then return err end

	local err, peer = _.getpeername(conn.no)

	if peer:port() ~= 80 then
		m.HOST = ("%s:%s"):format(options.host, options.port)
	else
		m.HOST = options.host
	end

	m.hub = self.hub
	m.conn = conn

	m.stream = m.conn:stream()
	m.parser = parser.Response(options.parser)

	m.response_to_request = {}
	local res_sender, res_recver = self.hub:pipe()
	self.hub:spawn(function() m:reader(res_recver) end)
	m.responses = res_sender
	return nil, m
end


function HTTP_mt:listen(port, host, config)
	config = config or {}

	options = Options(port, host, config)

	local err, serve = self.hub.tcp:listen(options)
	if err then return err end
	local m = setmetatable(
		{hub = self.hub, serve = serve, config = config},
		Listener_mt)
	m.sender, m.recver = self.hub:pipe()
	self.hub:spawn(m.loop, m)
	return nil, m
end


function HTTP_mt:droplet(port, host, config)
	return Droplet(self.hub, port, host, config)
end


local M_mt = {}
M_mt.__index = M_mt


M_mt.parser = parser
M_mt.Map = Map


function M_mt.__call(self, hub)
	return setmetatable({hub = hub}, HTTP_mt)
end


return setmetatable({Status = Status}, M_mt)
