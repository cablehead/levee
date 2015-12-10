local _ = require("levee")._


return {
	test_core = function()
		local t = {foo = "bar", more = "more\nnewline", nested = {1, {two = 2}, 3}}
		_.repr(t)
		t["t"] = t
		_.repr(t)
	end,
}
