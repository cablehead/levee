local HTTPParser = require("levee.parser.http")


local Server = {}


function Server.new(h, conn)
	local sender, recver = unpack(h:pipe())

	h:spawn(function()
		local parser = HTTPParser()

		function _iter(conn, parser)
			local buf = conn:recv()
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
				end

				return parser:value(buf:value())
			end
		end

		while true do
			parser:init_request()

			local iter = _iter(conn, parser)

			local r = {}

			r.method, r.path, r.version = iter()
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
