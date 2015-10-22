local ffi = require('ffi')
local C = ffi.C

local _ = require("levee")._


return {
	test_pipe_read_write = function()
		local err, r, w = _.pipe()
		assert(not err)

		assert.same({nil, 3}, {_.write(w, "foo")})
		assert.same({nil, "foo"}, {_.reads(r)})

		assert(not _.close(w))
		assert(_.close(w))

		local err = _.write(w, "foo")
		assert(err)

		local err = _.reads(r)
		assert(err)
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
}
