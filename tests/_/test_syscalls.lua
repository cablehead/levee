local ffi = require('ffi')
local C = ffi.C

local _ = require("levee")._


return {
	test_pipe_read_write = function()
		local r, w = _.pipe()

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

		local dir = _.path.dirname(path)
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

	test_net_in	= function()
		-- basic errors
		local err = _.listen(-3)
		assert(err)
		local err = _.accept(-3)
		assert(err)
		local err = _.getsockname(-3)
		assert(err)
		local err = _.getpeername(-3)
		assert(err)

		-- listen
		local err, l_no = _.socket(C.AF_INET, C.SOCK_STREAM)
		local err, l_no = _.listen(l_no, _.endpoint_in())
		assert(not err)
		-- attempt to bind to previously bound port
		local err, l_ep = _.getsockname(l_no)
		assert(not err)
		local err, alt_no = _.socket(C.AF_INET, C.SOCK_STREAM)
		local err = _.listen(alt_no, l_ep)
		assert(err)
		-- peername for listening socket makes no sense
		local err = _.getpeername(l_no)
		assert(err)

		-- connect
		local err, c_no = _.socket(C.AF_INET, C.SOCK_STREAM)
		local err, c_no = _.connect(c_no, l_ep)
		assert(not err)

		-- accept
		local err, s_no = _.accept(l_no)
		assert(not err)
		local err, p_ep = _.getpeername(s_no)
		assert(not err)
		local err, c_ep = _.getsockname(c_no)
		assert(not err)
		assert.equal(tostring(p_ep), tostring(c_ep))
	end,

	test_net_unix	= function()
		local name = os.tmpname()
		defer(function() os.remove(name) end)

		local err, l_no = _.socket(C.AF_UNIX, C.SOCK_STREAM)
		local err = _.listen(l_no, _.endpoint_unix(name))
		assert(err)
		os.remove(name)
		local err = _.listen(l_no, _.endpoint_unix(name))
		assert(not err)

		local err, c_no = _.socket(C.AF_UNIX, C.SOCK_STREAM)
		local err = _.connect(c_no, _.endpoint_unix(name))

		local err, s_no = _.accept(l_no)
		assert(not err)
		local err, p_ep = _.getpeername(s_no)
		assert(not err)
		local err, c_ep = _.getsockname(c_no)
		assert(not err)
		assert.equal(tostring(p_ep), tostring(c_ep))
		_.write(c_no, "foo")
		assert.equal(_.reads(s_no), "foo")
	end,

	test_gethostname = function()
		local err, name = _.gethostname()
		assert(not err)
	end,

	test_getrusage = function()
		local err, rusage = _.getrusage()
		assert(rusage.ru_maxrss > 0)
	end,

	test_getcurrentrss = function()
		local err, rss = _.getcurrentrss()
		assert(rss > 0)
	end,

	test_sendto_recvfrom = function()
		local len = 4096
		local buf = ffi.new("char[?]", len)

		local err, s = _.socket(C.AF_INET, C.SOCK_DGRAM)
		local err, s = _.bind(s, _.endpoint_in())
		local err, c1 = _.socket(C.AF_INET, C.SOCK_DGRAM)

		local err, s_ep = _.getsockname(s)
		local err, n = _.sendto(c1, s_ep, "foo")
		assert.equal(n, 3)

		local err, who, n = _.recvfrom(s, buf, len)
		assert.equal(ffi.string(buf, n), "foo")

		local err, n = _.sendto(s, who, "foobar")
		assert.equal(n, 6)

		local err, who, n = _.recvfrom(c1, buf, len)
		assert.equal(ffi.string(buf, n), "foobar")

		assert.equal(tostring(s_ep), tostring(who))
	end,

	test_fds = function()
		local err, s = _.socket(C.AF_INET, C.SOCK_DGRAM)
		local fds = _.fds()
		assert.contains(s, fds)
	end
}
