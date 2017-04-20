local levee = require("levee")
local _ = levee._
local d = levee.d

local filename = debug.getinfo(1, 'S').source:sub(2)
local path = _.path.dirname(filename)

local SERVER_OPTIONS = {
	key_file=path.."/tls_key", cert_file=path.."/tls_key.pub"}

local CLIENT_OPTIONS = {
	server_name="www.imgix.com", ca_file=path.."/tls_key.pub"}


return {
	test_raw = function()
		local TLS = require("levee.net.tls")

		local h = levee.Hub()

		local err, serve = h.stream:listen()
		local err, addr = serve:addr()

		local function server()
			local err, config = TLS.Config(SERVER_OPTIONS)
			local err, ctx = config:server()

			local err, conn = serve:recv()
			local err, conn = ctx:upgrade(conn)
			conn:handshake()

			assert.equal(conn:reads(), "foo")
			conn:write("bar")
			conn:close()
		end
		h:spawn(server)

		-- client
		local err, conn = h.stream:connect(addr:port())

		local err, config = TLS.Config(CLIENT_OPTIONS)
		local err, conn = config:upgrade(conn, CLIENT_OPTIONS.server_name)
		conn:handshake()

		conn:write("foo")
		assert.equal(conn:reads(), "bar")
		assert.equal(conn:reads(), nil)
	end,

	test_core = function()
		local h = levee.Hub()

		local err, serve = h.stream:listen({tls=SERVER_OPTIONS})
		local err, addr = serve:addr()

		local function server()
			local err, conn = serve:recv()
			assert.equal(conn:reads(), "foo")
			conn:write("bar")
			conn:close()
		end
		h:spawn(server)

		-- client
		local err, conn = h.stream:connect({port=addr:port(), tls=CLIENT_OPTIONS})
		conn:write("foo")
		assert.equal(conn:reads(), "bar")
		assert.equal(conn:reads(), nil)
	end,

	test_handshake_server_fail = function()
		local h = levee.Hub()

		local err, serve = h.stream:listen()
		local err, addr = serve:addr()

		local function server()
			local err, conn = serve:recv()
			conn:write(("X"):rep(100))
		end
		h:spawn(server)

		-- client
		local err, conn = h.stream:connect({port=addr:port(), tls=CLIENT_OPTIONS})
		assert(err)
	end,

	test_write_iovec = function()
		local h = levee.Hub()

		local err, serve = h.stream:listen({tls=SERVER_OPTIONS})
		local err, addr = serve:addr()

		local function server()
			local err, conn = serve:recv()
			local iov = d.Iovec()
			iov:write("foo")
			iov:write("bar")
			iov:write("baz")
			conn:writev(iov:value())
			conn:close()
		end
		h:spawn(server)

		-- client
		local err, conn = h.stream:connect({port=addr:port(), tls=CLIENT_OPTIONS})
		assert.equal(conn:reads(), "foobarbaz")
		assert.equal(conn:reads(), nil)
	end,
}
