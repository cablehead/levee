local levee = require("levee")
local _ = levee._


local script = [[
local levee = require("levee")
print("oh hai")
]]


return {
	test_core = function()
		local tmp = _.path.Path:tmpdir()
		defer(function() tmp:remove(true) end)

		tmp("foo.lua"):write(script)

		local options = {
			exe = tostring(tmp("foo")),
			file = tostring(tmp("foo.lua")),
		}

		require("levee.cmd").build.run(options)

		local h = levee.Hub()
		local child = h.process:spawn(options.exe)
		assert.equal(child.stdout:reads(), "oh hai\n")
		child.done:recv()
	end,
}
