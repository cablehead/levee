local levee = require("levee")

local ffi = require("ffi")
local C = ffi.C





return {
	test_io_close_read = function()
		levee.run(function(h)
			local fds = ffi.new("int[2]")
			assert(C.pipe(fds) == 0)
			local r, w = h.io:r(fds[0]), h.io:w(fds[1])

			-- TODO: this is needed as poller doesn't flush en_in before closing fd
			w:send("foo")
			assert.equal(r:recv(), "foo")

			r:close()
			assert.equal(r:recv(), nil)

			-- it takes a turn to detect the fd closed
			w:send("foo")
			assert.equal(w:send("foo"), nil)
		end)
	end,

	test_io_close_write = function()
		levee.run(function(h)
			local fds = ffi.new("int[2]")
			assert(C.pipe(fds) == 0)
			local r, w = h.io:r(fds[0]), h.io:w(fds[1])

			-- TODO: this is needed as poller doesn't flush en_in before closing fd
			w:send("foo")
			assert.equal(r:recv(), "foo")

			w:close()
		end)
	end,
}
