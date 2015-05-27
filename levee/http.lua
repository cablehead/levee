local HTTPParser = require("levee.parser.http")
local meta = require("levee.meta")


local VERSION = "HTTP/1.1"


function send_headers(conn, headers)
	for key, value in pairs(headers) do
		conn:send(("%s: %s\r\n"):format(key, value))
	end
	conn:send("\r\n")
end


function parser_recver(h, conn, parser, init)
	local sender, recver = unpack(h:pipe())

	init()

	h:spawn(function()
		for buf in conn do
			while true do
				local rc = parser:next(buf:value())
				if rc < 0 then error("TODO: parse error") end

				-- print("PARSER", rc, parser:is_done())
				if parser:has_value() then
					sender:send({parser:value(buf:value())})
				end

				if parser:is_done() then
					sender:send({nil})
					init()
				end

				if rc > 0 then
					buf:trim(rc)
				else
					break
				end
			end
		end
	end)

	return recver
end


--
-- HTTP Client

local Client = {}
Client.__index = Client


function Client.new(h, conn)
	local parser = HTTPParser()

	local self = {
		h = h,
		conn = conn,
		parser = parser_recver(
			h, conn, parser, function() parser:init_response() end),
		requests = h:pipe(),
		responses = h:pipe(),
	}

	h:spawn(Client.writer, self)
	h:spawn(Client.reader, self)

	return setmetatable(self, Client)
end


function Client:close()
	self.conn:close()
	self.requests:close()
	self.responses:close()
end


function Client:default_headers(headers)
	-- TODO: Host
	local ret = {
		["User-Agent"] = "levee/" .. meta.version,
		Accept = "*/*",
	}
	if headers then
		for key, value in pairs(headers) do
			ret[key] = value
		end
	end
	return ret
end


function Client:writer()
	for request in self.requests do
		local method, path, params, headers, data = unpack(request)
		-- TODO: params
		self.conn:send(("%s %s %s\r\n"):format(method, path, VERSION))

		headers = self:default_headers(headers)
		if data then
			headers["Content-Length"] = #data
		end
		send_headers(self.conn, self:default_headers(headers))

		if data then
			self.conn:send(data)
		end
	end
end


function Client:reader()
	for response in self.responses do
		local r = {headers={}}
		r.code, r.reason, r.version = unpack(self.parser:recv())
		while true do
			local key, value = unpack(self.parser:recv())
			if not key then break end
			r.headers[key] = value
		end
		r.body = unpack(self.parser:recv())
		response:send(r)
		response:close()
	end
end


function Client:request(method, path, params, headers, data)
	local sender, recver = unpack(self.h:pipe())
	self.requests:send({method, path, params, headers, data})
	self.responses:send(sender)
	return recver
end


function Client:get(path, options)
	options = options or {}
	return self:request("GET", path, options.params, options.headers)
end


function Client:post(path, options)
	options = options or {}
	return self:request(
		"POST", path, options.params, options.headers, options.data)
end


--
-- HTTP Server

local Server = {}
Server.__index = Server


function Server.new(h, conn)
	local parser = HTTPParser()

	local self = {
		h = h,
		conn = conn,
		parser = parser_recver(
			h, conn, parser, function() parser:init_request() end),
		requests = h:pipe(),
	}

	h:spawn(Server.reader, self)

	return setmetatable(self, Server)
end


function Server:close()
	self.conn:close()
	self.requests:close()
end


function Server:__call()
	return self.requests:recv()
end


function Server:recv()
	return self.requests:recv()
end


function Server:reader()
	while true do
		local r = {headers={}}

		r.reply = function(status, headers, body)
			self.conn:send(("%s %s %s\r\n"):format(VERSION, unpack(status)))
			-- TODO: Date
			headers['Date'] = "Fri, 22 May 2015 19:44:50 GMT"
			headers['Content-Length'] = #body

			send_headers(self.conn, headers)
			self.conn:send(body)
		end

		r.method, r.path, r.version = unpack(self.parser:recv())
		if r.method == nil then
			conn:close()
			return
		end

		while true do
			local key, value = unpack(self.parser:recv())
			if key == false then break end
			r.headers[key] = value
		end

		r.body = unpack(self.parser:recv())

		self.requests:send(r)
	end
end


return function(h)
	local M = {}

	function M:connect(port, host)
		local conn = h.tcp:connect(port, host)
		return Client.new(h, conn)
	end

	function M:listen(port, host)
		local serve = h.tcp:listen(port, host)
		local sender, recver = unpack(h:pipe())
		h:spawn(function()
			while true do
				local conn = serve:recv()
				sender:send(Server.new(h, conn))
			end
		end)
		return setmetatable({
			recv = function()
				return recver:recv()
			end,
			close = function()
				serve:close()
				return recver:close()
			end
		}, {
			__call = function()
				return recver:recv()
			end,
		})
	end

	return M
end
