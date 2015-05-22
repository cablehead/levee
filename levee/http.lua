local HTTPParser = require("levee.parser.http")


local Server = {}


function Server.new(h, conn)
	local sender, recver = unpack(h:pipe())

	h:spawn(function()
		local parser = HTTPParser()

		function _iter(conn, parser)
			local buf = conn:recv()
			if buf == nil then return end
			local rc

			return function()
				if rc then
					buf:trim(rc)
				end

				while true do
					rc = parser:next(buf:value())
					if rc < 0 then error("TODO: parse error") end
					if rc > 0 then break end
					if parser:is_done() then return end
					buf = conn:recv()
					if buf == nil then return end
				end

				return parser:value(buf:value())
			end
		end

		local iter = _iter(conn, parser)
		if iter == nil then
			conn:close()
			return
		end

		while true do
			parser:init_request()

			local r = {}

			r.reply = function(status, headers, body)
				conn:send(("HTTP/1.1 %s %s\r\n"):format(unpack(status)))
				headers['Date'] = "Fri, 22 May 2015 19:44:50 GMT"
				headers['Content-Length'] = #body
				for key, value in pairs(headers) do
					conn:send(("%s: %s\r\n"):format(key, value))
				end
				conn:send("\r\n")
				conn:send(body)
			end

			r.method, r.path, r.version = iter()
			if r.method == nil then
				conn:close()
				return
			end

			r.headers = {}

			while true do
				local key, value = iter()
				if key == false then break end
				r.headers[key] = value
			end

			r.body = iter()
			assert(parser:is_done())

			sender:send(r)
		end
	end)

	return recver
end


return function(h)
	local M = {}

	function M:listen(port, host)
		local serve = h.tcp:listen(port, host)
		local sender, recver = unpack(h:pipe())
		h:spawn(function()
			while true do
				local conn = serve:recv()
				sender:send(Server.new(h, conn))
			end
		end)
		return recver
	end

	return M
end
