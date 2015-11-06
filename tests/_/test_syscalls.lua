local ffi = require('ffi')
local C = ffi.C

local _ = require("levee")._


return {
	test_pipe_read_write = function()
		local err, r, w = _.pipe()
		assert(not err)

		assert.same({nil, 3}, {_.write(w, "foo")})
		assert.equal("foo", _.reads(r))

		assert(not _.close(w))
		assert(_.close(w))

		local err = _.write(w, "foo")
		assert(err)
		assert(not _.reads(r))
	end,

	test_open_stat_fstat = function()
		local err, no = _.open("foo121", C.O_RDONLY, C.O_NONBLOCK)
		assert(err)
		local err, info = _.stat("foo121")
		assert(err)
		local err, info = _.fstat(-3)
		assert(err)

		local path = os.tmpname()
		local err, no = _.open(path, C.O_RDONLY, C.O_NONBLOCK)
		assert(not err)
		local err, info = _.stat(path)
		assert(not err)
		assert(info:is_reg())
		assert(not info:is_dir())
		local err, info = _.fstat(no)
		assert(not err)
		assert(info:is_reg())
		assert(not info:is_dir())

		local dir = dirname(path)
		local err, no = _.open(dir, C.O_RDONLY, C.O_NONBLOCK)
		assert(not err)
		local err, info = _.stat(dir)
		assert(not err)
		assert(not info:is_reg())
		assert(info:is_dir())
		local err, info = _.fstat(no)
		assert(not err)
		assert(not info:is_reg())
		assert(info:is_dir())

		os.remove(path)
	end,

	test_fcntl_block_nonblock = function()
		local err, flags = _.fcntl(-3, C.F_GETFL)
		assert(err)

		local path = os.tmpname()
		local err, no = _.open(path, C.O_RDONLY)

		local err, flags = _.fcntl(no, C.F_GETFL)
		assert(not err)
		assert(bit.band(flags, C.O_NONBLOCK) == 0)

		local err = _.fcntl_nonblock(-3)
		assert(err)

		local err = _.fcntl_nonblock(no)
		assert(not err)
		local err, flags = _.fcntl(no, C.F_GETFL)
		assert(not err)
		assert(bit.band(flags, C.O_NONBLOCK) > 0)
		local err = _.fcntl_nonblock(no)
		assert(not err)

		local err = _.fcntl_block(no)
		assert(not err)
		local err, flags = _.fcntl(no, C.F_GETFL)
		assert(not err)
		assert(bit.band(flags, C.O_NONBLOCK) == 0)
		local err = _.fcntl_block(no)
		assert(not err)

		os.remove(path)
	end,

	test_net = function()
		-- basic errors
		local err = _.getaddrinfo("foo")
		assert(err)
		local err = _.listen(-3, C.SOCK_STREAM)
		assert(err)
		local err = _.accept(-3, C.SOCK_STREAM)
		assert(err)
		local err = _.connect("foo")
		assert(err)
		local err = _.connect("127.0.0.1", 63529)
		assert(err)
		local err = _.getsockname(-3)
		assert(err)
		local err = _.getpeername(-3)
		assert(err)

		-- listen
		local err, l_no = _.listen(C.AF_INET, C.SOCK_STREAM)
		assert(not err)
		-- attempt to bind to previously bound port
		local err, ep = _.getsockname(l_no)
		assert(not err)
		local port = ep:port()
		local err = _.listen(C.AF_INET, C.SOCK_STREAM, nil, port)
		assert(err)
		-- peername for listening socket makes no sense
		local err, ep = _.getpeername(l_no)
		assert(err)

		-- connect
		local err, c_no = _.connect("127.0.0.1", port)
		assert(not err)

		local err, c_ep = _.getsockname(c_no)
		assert(not err)
		local err, ep = _.getpeername(c_no)
		assert(not err)
		assert.equal(ep:port(), port)

		-- accept
		local err, s_no = _.accept(l_no)
		assert(not err)
		local err, ep = _.getsockname(s_no)
		assert(not err)
		assert.equal(ep:port(), port)
		local err, ep = _.getpeername(s_no)
		assert(not err)
		assert.equal(ep:port(), c_ep:port())
	end,
}
