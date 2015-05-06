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

		local d = time.localdate()
		assert(math.floor(d:time():seconds()) == math.floor(time.now():seconds()))

		local utc = t:utcdate()
		local loc = t:localdate()
		assert(utc == loc)
		assert(utc:time() == loc:time())
		assert(utc:iso8601() == "2015-05-05T18:51:17.736409Z")
		assert(loc:utcdate():iso8601() == "2015-05-05T18:51:17.736409Z")
		assert(time.iso8601("2015-05-05T18:51:17.736409Z") == utc)
		assert(time.iso8601("2015-05-05T11:51:17.736409-07:00") == loc)
		assert(time.parse("2015-05-05T18:51:17.736409Z") == utc)
		assert(time.parse("2015-05-05T11:51:17.736409-07:00") == loc)

		utc = time.Date(2015, 5, 5, 18, 51, 17)
		loc = utc:localdate()
		assert(utc == loc)
		assert(utc:time() == loc:time())
		assert(utc:http() == "Tue, 05 May 2015 18:51:17 GMT")
		assert(time.http("Tue, 05 May 2015 18:51:17 GMT") == utc)
		assert(time.parse("Tue, 05 May 2015 18:51:17 GMT") == utc)
	end,
	test_timer = function()
		local time = require("levee.time")
		local ffi = require("ffi")
		ffi.cdef[[int usleep(unsigned long);]]

		local timer = time.Timer()

		timer:start()
		ffi.C.usleep(100000)
		timer:finish()

		local ms = timer:milliseconds()
		assert(ms >= 100 and ms <= 110)
		-- time will adjust to use the best unit
		assert(timer:time():sub(-2) == "ms")
	end,
}
