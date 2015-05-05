return {
	test_time = function()
		local time = require("levee.time")
		local a = time.Time(100)
		local b = time.Time(200)
		assert((a + b) == time.Time(300))
		assert((a - b) == time.Time(-100))
		assert((b - a) == time.Time(100))
		assert((a + 200.5) == time.Time(300.5))
		assert((a + 200.5) == 300.5)
	end,
	test_date = function()
		local time = require("levee.time")
		local t = time.Time(1430851877.73641)
		local utc = t:utcdate()
		local loc = t:localdate()
		assert(tostring(utc) == "2015-05-05T18:51:17.736409Z")
		assert(tostring(loc:utcdate()) == "2015-05-05T18:51:17.736409Z")
		assert(tostring(loc) == tostring(utc:localdate()))
		assert(utc == loc)
		assert(utc:time() == loc:time())

		local d2 = time.localdate()
		assert(math.floor(d2:time():seconds()) == math.floor(time.now():seconds()))
	end,
	test_timer = function()
		local time = require("levee.time")
		local ffi = require("ffi")
		ffi.cdef[[int usleep(unsigned long);]]

		local timer = time.Timer()
		ffi.C.usleep(100000)
		timer:finish()
		local ms = timer:milliseconds()
		assert(ms >= 100 and ms <= 110)
		-- time will adjust to use the best unit
		assert(timer:time() == tostring(ms) .. "ms")
	end
}
