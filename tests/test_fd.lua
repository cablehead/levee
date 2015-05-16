local fd = require("levee.sys.fd")


return {
	test_register = function()
		local levee = require("levee")

		levee.run(function(h)
			local r, w = fd.pipe()
			r:nonblock(true)
			w:nonblock(true)

			local pollin = h:register(r.no, true)
			local _, pollout = h:register(w.no, nil, true)

			assert.True(pollout:recv())

			w:write("x")
			assert.True(pollin:recv())

			-- trigger EAGAIN on write
			while true do
				local n = w:write("x")
				if n == -1 then
					break
				end
			end
			assert.True(pollin:recv())

			r:reads()
			assert.True(pollout:recv())
			assert.True(pollin:recv())

			-- trigger EAGAIN on read
			while true do
				local n = r:reads()
				if not n then break end
			end
			assert.True(pollout:recv())

			h:unregister(r.no)
			assert.equal(pollout:recv(), nil)
			h:unregister(w.no)
		end)
	end,
}
