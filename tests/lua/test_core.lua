local sys = require("levee.sys")

return {
	test_register = function()
		local levee = require("levee")

		levee.run(function(h)
			local r, w = sys.fd.pipe()
			sys.fd.nonblock(r, true)
			sys.fd.nonblock(w, true)

			local pollin = h:register(r, true)
			local _, pollout = h:register(w, nil, true)

			assert.True(pollout:recv())

			sys.fd.write(w, "x")
			assert.True(pollin:recv())

			-- trigger EAGAIN on write
			while true do
				local n = sys.fd.write(w, "x")
				if n == -1 then
					break
				end
			end
			assert.True(pollin:recv())

			sys.fd.reads(r)
			assert.True(pollout:recv())
			assert.True(pollin:recv())

			-- trigger EAGAIN on read
			while true do
				local n = sys.fd.reads(r)
				if not n then break end
			end
			assert.True(pollout:recv())

			h:unregister(r)
			assert.equal(pollout:recv(), nil)
			h:unregister(w)
		end)
	end,
}
