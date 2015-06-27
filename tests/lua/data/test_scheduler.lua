return {
	test_core = function()
		local s = require("levee.scheduler")()

		local ok = false
		local function foo() ok = true end

		local co = coroutine.create(foo)
		s:add(1000ULL, co)

		local ms, co = s:pop()
		coroutine.resume(co)
		assert(ok)
	end,
}
