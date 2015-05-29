--[[
local levee = require("levee")
local sys = require("levee.sys")

local ffi = require("ffi")
local C = ffi.C
]]--


return {
	test_io_close_read = function()
		if true then return 'SKIP' end
		levee.run(function(h)
			local r, w = sys.fd.pipe()
			local r, w = h.io:r(r), h.io:w(w)

			collectgarbage("collect")

			-- TODO: this is needed as poller doesn't flush en_in before closing fd
			w:send("foo")
			assert.equal(r:recv():take_s(), "foo")

			r:close()
			assert.equal(r:recv(), nil)

			-- it takes a turn to detect the fd closed
			w:send("foo")
			assert.equal(w:send("foo"), nil)
		end)
	end,

	test_io_close_write = function()
		if true then return 'SKIP' end
		levee.run(function(h)
			local r, w = sys.fd.pipe()
			local r, w = h.io:r(r), h.io:w(w)

			collectgarbage("collect")

			-- TODO: this is needed as poller doesn't flush en_in before closing fd
			w:send("foo")
			assert.equal(r:recv():take_s(), "foo")

			w:close()
		end)
	end,
}
