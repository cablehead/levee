local _ = require("levee")._


return {
	test_time = function()
		local a = _.time.Time(100)
		local b = _.time.Time(200)
		assert((a + b) == _.time.Time(300))
		assert((a - b) == _.time.Time(-100))
		assert((b - a) == _.time.Time(100))
		assert((a + 200.5) == _.time.Time(300.5))
		assert((a + 200.5) == 300.5)
	end,
	test_date = function()
		local t = _.time.Time(1430851877.73641)

		local d = _.time.localdate()
		assert(math.floor(d:time():seconds()) == math.floor(_.time.now():seconds()))

		local utc = t:utcdate()
		local loc = t:localdate()
		assert.equals(utc, loc)
		assert.equals(utc:time(), loc:time())
		assert.equals("2015-05-05T18:51:17.736409Z", utc:iso8601())
		assert.equals("2015-05-05T18:51:17.736409Z", loc:utcdate():iso8601())
		assert.equals(utc, _.time.parse_iso8601("2015-05-05T18:51:17.736409Z"))
		assert.equals(loc, _.time.parse_iso8601("2015-05-05T11:51:17.736409-07:00"))
		assert.equals(utc, _.time.parse("2015-05-05T18:51:17.736409Z"))
		assert.equals(loc, _.time.parse("2015-05-05T11:51:17.736409-07:00"))

		utc = _.time.Date(2015, 5, 5, 18, 51, 17)
		loc = utc:localdate()
		assert.equals(utc, loc)
		assert.equals(utc:time(), loc:time())
		assert.equals("Tue, 05 May 2015 18:51:17 GMT", utc:http())
		assert.equals(utc, _.time.parse_http("Tue, 05 May 2015 18:51:17 GMT"))
		assert.equals(utc, _.time.parse("Tue, 05 May 2015 18:51:17 GMT"))

		utc = utc:replace(nil, nil, nil, 20, 0, 0)
		assert.equals("Tue, 05 May 2015 20:00:00 GMT", utc:http())

	end,
	test_timer = function()
		local ffi = require("ffi")
		ffi.cdef[[int usleep(unsigned long);]]

		local timer = _.time.Timer()

		timer:start()
		ffi.C.usleep(100000)
		timer:finish()

		local ms = timer:milliseconds()
		assert(ms >= 100 and ms <= 110)
		-- time will adjust to use the best unit
		assert(timer:time():sub(-2) == "ms")
	end,
}
