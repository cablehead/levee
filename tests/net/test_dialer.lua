local levee = require("levee")

local _ = levee._
local errors = levee.errors


local function server(h)
	local err, serve = h.stream:listen()
	local err, addr = serve:addr()
	serve.port = addr:port()
	assert(h:in_use())
	return nil, serve
end


local function __tests(async)
	return {
		test_core = function()
			local h = levee.Hub()

			local err, serve = server(h)

			local err, conn = h.dialer:dial(
				C.AF_INET, C.SOCK_STREAM, "127.0.0.1", serve.port, nil, async)
			assert(not err)
			assert(conn.no > 0)
			local err, s = serve:recv()
			s:close()
			h:unregister(conn.no, true, true)
			h:continue()
			serve:close()

			local err, conn = h.dialer:dial(
				C.AF_INET, C.SOCK_STREAM, "localhost", serve.port, nil, async)
			assert.equal(err, errors.system.ECONNREFUSED)
			assert(not conn)

			assert(not h:in_use())
		end,

		test_ok_port_as_string = function()
			local h = levee.Hub()

			local err, serve = server(h)

			local err, conn = h.dialer:dial(
				C.AF_INET, C.SOCK_STREAM, "127.0.0.1", tostring(serve.port), nil, async)
			assert(not err)
			assert(conn.no > 0)
			local err, s = serve:recv()
			s:close()
			h:unregister(conn.no, true, true)
			h:continue()
			serve:close()
			assert(not h:in_use())
		end,

		test_unknown = function()
			local h = levee.Hub()

			local err, conn = h.dialer:dial(
				C.AF_INET, C.SOCK_STREAM, "kdkd", 5555, nil, async)
			if async then
				assert.contains(err, {errors.dns.NXDOMAIN, errors.addr.ENODATA})
			else
				assert.equal(err, errors.addr.ENONAME)
			end
		end,

		test_timeout = function()
			local h = levee.Hub()

			local err, conn = h.dialer:dial(
				C.AF_INET, C.SOCK_STREAM, "10.244.245.246", 5555, 20, async)
			assert.equal(err, errors.TIMEOUT)
		end,

		test_port_out_of_range = function()
			local h = levee.Hub()
			local err, conn = h.dialer:dial(
				C.AF_INET, C.SOCK_STREAM, "127.0.0.1", 70000, nil, async)
			assert.equal(err, errors.addr.ENONAME)
		end,

		test_unknown_service = function()
			local h = levee.Hub()
			local err, conn = h.dialer:dial(
				C.AF_INET, C.SOCK_STREAM, "127.0.0.1", "xxx", nil, async)
			assert.equal(err, errors.addr.ENONAME)
		end,
	}
end


return {
	sync = __tests(),
	async = __tests(true),
}
