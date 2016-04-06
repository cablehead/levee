local levee = require("levee")
local _ = levee._

return {
	test_core = function()
		local h = require("levee").Hub()

		local buf = levee.d.Buffer(4096)

		local err, s = h.udp:listen(9000)
		local err, c = h.udp:dial(9000)

		c:write("123")
		s:readinto(buf)
		assert.equal(buf:take(), "123")
	end,
}
